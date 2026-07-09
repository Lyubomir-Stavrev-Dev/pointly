import Foundation
import Combine

/// License-key unlock for the direct-distribution (website) build.
/// Uses the Lemon Squeezy License API — activation/validation endpoints are
/// public and need no API secret, so nothing sensitive ships in the binary.
/// The App Store build never shows license UI (see #if DIRECT_BUILD in
/// ProPaywallView); StoreKit remains the only unlock path there.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var isLicensed = false
    @Published private(set) var activationInProgress = false
    @Published private(set) var errorMessage: String? = nil

    private let keyStore      = "directLicenseKey"
    private let instanceStore = "directLicenseInstanceID"
    private let checkedStore  = "directLicenseLastValidated"

    private let activateURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!
    private let validateURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses/validate")!

    private init() {
        if UserDefaults.standard.string(forKey: keyStore) != nil {
            isLicensed = true
            Task { await revalidateQuietly() }
        }
    }

    // MARK: - Activate (called from the paywall's license field)

    @MainActor
    func activate(key: String) async {
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

    // MARK: - Background revalidation (never hard-revokes while offline)

    private func revalidateQuietly() async {
        guard let key = UserDefaults.standard.string(forKey: keyStore) else { return }
        let instance = UserDefaults.standard.string(forKey: instanceStore) ?? ""
        var body = ["license_key": key]
        if !instance.isEmpty { body["instance_id"] = instance }

        guard let json = try? await post(validateURL, body: body) else { return } // offline → keep cached state
        if json["valid"] as? Bool == false {
            // Explicitly invalid (refunded/disabled) — revoke.
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: keyStore)
                UserDefaults.standard.removeObject(forKey: instanceStore)
                isLicensed = false
            }
        } else {
            UserDefaults.standard.set(Date(), forKey: checkedStore)
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
