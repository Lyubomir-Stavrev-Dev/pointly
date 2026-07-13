import Foundation
import StoreKit
import Combine

// MARK: - ProPlan

enum ProPlan: String, CaseIterable {
    case annual   = "annual"
    case lifetime = "lifetime"

    var productID: String {
        switch self {
        case .annual:   return "com.pointly.macos.pro.annual"
        case .lifetime: return "com.pointly.macos.pro.lifetime"
        }
    }
    var displayName: String {
        switch self {
        case .annual:   return "Pro"
        case .lifetime: return "Pro+"
        }
    }
    var fallbackPrice: String {
        switch self {
        case .annual:   return "€12.99"
        case .lifetime: return "€39.99"
        }
    }
    var period: String {
        switch self {
        case .annual:   return "/ year"
        case .lifetime: return "one-time"
        }
    }
    var badge: String {
        switch self {
        case .annual:   return "Most Popular"
        case .lifetime: return "Best Value"
        }
    }
}

// MARK: - ProManager

final class ProManager: ObservableObject {
    static let shared = ProManager()

    @Published private(set) var isPro              = false
    @Published private(set) var purchaseInProgress = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var loadedProducts: [String: Product] = [:]

    private var updatesTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        #if DEBUG
        // Dev-only unlock for demos/recordings: defaults write com.pointly.macos debugForcePro -bool true
        if UserDefaults.standard.bool(forKey: "debugForcePro") { isPro = true }
        #endif
        #if DIRECT_BUILD
        // Website build: a valid license key unlocks Pro (StoreKit is App Store-only).
        LicenseManager.shared.$isLicensed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] licensed in
                guard let self else { return }
                if licensed { self.isPro = true } else if !licensed && self.isPro {
                    // license revoked (refund) and no StoreKit entitlement in this build
                    self.isPro = false
                }
            }
            .store(in: &cancellables)
        #endif
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Locked tools

    static let proTools: Set<DrawingTool> = [.blurBrush, .laserPointer, .spotlight, .dotPen, .cutMove]

    func isLocked(_ tool: DrawingTool) -> Bool {
        !isPro && Self.proTools.contains(tool)
    }

    func product(for plan: ProPlan) -> Product? {
        loadedProducts[plan.productID]
    }

    // MARK: - Load Products

    private func loadProducts() async {
        let ids = ProPlan.allCases.map(\.productID)
        do {
            let products = try await Product.products(for: Set(ids))
            await MainActor.run {
                for p in products { loadedProducts[p.id] = p }
            }
        } catch {
            // Not available — no App Store connection or sandbox not configured yet
        }
    }

    // MARK: - Purchase

    func purchase(plan: ProPlan = .annual) async {
        await MainActor.run { purchaseInProgress = true; errorMessage = nil }
        defer { Task { @MainActor in self.purchaseInProgress = false } }

        guard let product = loadedProducts[plan.productID] else {
            await MainActor.run {
                errorMessage = "Product unavailable. Check your connection or try again later."
            }
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await MainActor.run { isPro = true }
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                await MainActor.run {
                    errorMessage = "Purchase is pending approval (e.g. Ask to Buy)."
                }
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        await MainActor.run { purchaseInProgress = true; errorMessage = nil }
        defer { Task { @MainActor in self.purchaseInProgress = false } }

        // Force a full App Store re-sync (required for restore on a fresh Mac /
        // new Apple ID — the local transaction cache alone can be empty).
        // If the user cancels the sign-in, fall through to the local check so a
        // cached purchase still restores.
        try? await AppStore.sync()

        await refreshEntitlements()

        await MainActor.run {
            if !isPro { errorMessage = "No active purchase found for this Apple ID." }
        }
    }

    // MARK: - Entitlement Check

    private func refreshEntitlements() async {
        let proIDs = Set(ProPlan.allCases.map(\.productID))
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard proIDs.contains(tx.productID) else { continue }
            guard tx.revocationDate == nil else { continue }
            entitled = true
            break
        }
        // No valid entitlement must revoke Pro (refunds/expiry) — but never
        // clobber the other unlock channels.
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugForcePro") { entitled = true }
        #endif
        #if DIRECT_BUILD
        if LicenseManager.shared.isLicensed { entitled = true }
        #endif
        let isEntitled = entitled
        await MainActor.run { isPro = isEntitled }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            let proIDs = Set(ProPlan.allCases.map(\.productID))
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                guard proIDs.contains(tx.productID) else { continue }
                await self?.handleTransaction(tx)
            }
        }
    }

    private func handleTransaction(_ tx: Transaction) async {
        if tx.revocationDate == nil {
            await MainActor.run { isPro = true }
        } else {
            // Refunded or revoked
            await refreshEntitlements()
        }
        await tx.finish()
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let showPaywall        = Notification.Name("ShowProPaywall")
    static let showPaywallForPlan = Notification.Name("ShowProPaywallForPlan")
}
