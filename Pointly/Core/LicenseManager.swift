import Foundation
import Combine

/// License-key unlock for the direct-distribution (website) build.
/// Talks to the Pointly licensing Worker (Cloudflare) which issues keys after a
/// Stripe purchase and validates them here. Endpoints need no secret, so nothing
/// sensitive ships in the binary. The App Store build never shows license UI
/// (see #if DIRECT_BUILD in ProPaywallView); StoreKit remains its only unlock path.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var isLicensed = false
    @Published private(set) var activationInProgress = false
    @Published private(set) var errorMessage: String? = nil

    private let keyStore      = "directLicenseKey"
    private let instanceStore = "directLicenseInstanceID"
    private let checkedStore  = "directLicenseLastValidated"

    private static let apiBase = "https://pointly-licenses.lyubomirstavrev02.workers.dev/api"
    private let activateURL = URL(string: apiBase + "/activate")!
    private let validateURL = URL(string: apiBase + "/validate")!

    /// Offline grace period: a cached license keeps working without reaching
    /// the server for this long, then Pro degrades until revalidation succeeds.
    private static let offlineGraceDays = 30.0

    private init() {
        // A key alone grants nothing — it must come with a successful
        // server-validation timestamp inside the grace window. This stops the
        // `defaults write … directLicenseKey x` one-liner from unlocking Pro:
        // a planted key stays locked until the server confirms it.
        if UserDefaults.standard.string(forKey: keyStore) != nil {
            if let lastValidated = UserDefaults.standard.object(forKey: checkedStore) as? Date,
               Date().timeIntervalSince(lastValidated) < Self.offlineGraceDays * 86_400 {
                isLicensed = true
            }
            Task { await revalidateQuietly() }
        }
    }

    // MARK: - Activate (called from the paywall's license field)

    @MainActor
    func activate(key: String) async {
        guard !activationInProgress else { return }   // Return-key mashing burns activation seats
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Enter your license key."; return }
        activationInProgress = true
        errorMessage = nil
        defer { activationInProgress = false }

        do {
            let host = Host.current().localizedName ?? "Mac"
            let body = ["license_key": trimmed, "instance_name": host]
            let json = try await post(activateURL, body: body)

            if json["activated"] as? Bool == true {
                let instanceID = ((json["instance"] as? [String: Any])?["id"] as? String) ?? ""
                UserDefaults.standard.set(trimmed, forKey: keyStore)
                UserDefaults.standard.set(instanceID, forKey: instanceStore)
                UserDefaults.standard.set(Date(), forKey: checkedStore)
                isLicensed = true
            } else {
                errorMessage = (json["error"] as? String) ?? "This license key could not be activated."
            }
        } catch {
            errorMessage = "Couldn't reach the license server. Check your connection and try again."
        }
    }

    @MainActor
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Background revalidation (never hard-revokes while offline)

    private func revalidateQuietly() async {
        guard let key = UserDefaults.standard.string(forKey: keyStore) else { return }
        let instance = UserDefaults.standard.string(forKey: instanceStore) ?? ""
        var body = ["license_key": key]
        if !instance.isEmpty { body["instance_id"] = instance }

        guard let json = try? await post(validateURL, body: body) else { return } // offline → keep cached state
        switch json["valid"] as? Bool {
        case false:
            // Explicitly invalid (refunded/disabled/fake) — revoke.
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: keyStore)
                UserDefaults.standard.removeObject(forKey: instanceStore)
                UserDefaults.standard.removeObject(forKey: checkedStore)
                isLicensed = false
            }
        case true:
            // Confirmed — refresh the grace window and (re)grant, covering a
            // valid key whose grace had lapsed while offline.
            await MainActor.run {
                UserDefaults.standard.set(Date(), forKey: checkedStore)
                isLicensed = true
            }
        default:
            break // malformed response (worker error page etc.) — don't extend grace
        }
    }

    // MARK: - HTTP

    private func post(_ url: URL, body: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
