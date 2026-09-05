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
        // Shown only until StoreKit products load. The App Store build must not
        // hardcode a currency (wrong on most storefronts) — show a placeholder.
        // The direct build's Stripe prices really are EUR.
        #if DIRECT_BUILD
        switch self {
        case .annual:   return "€12.99"
        case .lifetime: return "€39.99"
        }
        #else
        return "…"
        #endif
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

    // Spin-wheel welcome offer: a separate discounted lifetime non-consumable
    // (60% off Pro+). Must exist in App Store Connect at the discounted price.
    static let spinOfferProductID = "com.pointly.macos.pro.lifetime.spin60"
    // Direct build: Stripe promotion code applied on the buy page instead.
    static let spinOfferPromoCode = "SPIN60"

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
        // Dev-only free-tier simulation: defaults write com.pointly.macos debugForceFree -bool true
        if UserDefaults.standard.bool(forKey: "debugForceFree") { isPro = false; return }
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
        // Re-check entitlements whenever the app comes back to the foreground —
        // covers promo codes / renewals redeemed while the app was inactive.
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refreshEntitlements() } }
            .store(in: &cancellables)
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Locked tools

    static let proTools: Set<DrawingTool> = [.blurBrush, .laserPointer, .spotlight, .dotPen, .cutMove,
                                             .stepBadge, .textCallout]

    func isLocked(_ tool: DrawingTool) -> Bool {
        !isPro && Self.proTools.contains(tool)
    }

    func product(for plan: ProPlan) -> Product? {
        loadedProducts[plan.productID]
    }

    var spinOfferProduct: Product? {
        loadedProducts[Self.spinOfferProductID]
    }

    /// Every product ID that unlocks Pro (plans + the spin-wheel offer).
    private static var allProProductIDs: Set<String> {
        Set(ProPlan.allCases.map(\.productID)).union([spinOfferProductID])
    }

    // MARK: - Spin-wheel welcome offer

    // One-shot: shown a single time, to new users only (first 14 days), after
    // they decline the paywall. Visibility is decoupled from product loading —
    // the wheel shows regardless, and the purchase path retries loading if the
    // product isn't ready yet (handles slow/sandbox StoreKit environments).
    var spinOfferAvailable: Bool {
        #if DEBUG
        // Dev-only, for demos/tests (bypasses the one-shot flag):
        // defaults write com.pointly.macos debugForceSpinOffer -bool true
        if UserDefaults.standard.bool(forKey: "debugForceSpinOffer") { return !isPro }
        #endif
        guard !isPro else { return false }
        guard !UserDefaults.standard.bool(forKey: "spinOfferShown") else { return false }
        let defaults = UserDefaults.standard
        let firstLaunch = defaults.object(forKey: "firstLaunchDate") as? Date ?? {
            let now = Date()
            defaults.set(now, forKey: "firstLaunchDate")
            return now
        }()
        guard Date().timeIntervalSince(firstLaunch) < 14 * 24 * 3600 else { return false }
        return true
    }

    func markSpinOfferShown() {
        UserDefaults.standard.set(true, forKey: "spinOfferShown")
    }

    // MARK: - Load Products

    private func loadProducts() async {
        let ids = Self.allProProductIDs
        do {
            let products = try await Product.products(for: Set(ids))
            await MainActor.run {
                for p in products { loadedProducts[p.id] = p }
            }
        } catch {
            // Not available — no App Store connection or sandbox not configured yet
        }
    }

    // Called from the paywall's onAppear — products load once at launch, so an
    // offline launch would otherwise brick purchasing for the whole session.
    func ensureProductsLoaded() {
        guard loadedProducts.isEmpty else { return }
        Task { await loadProducts() }
    }

    // The singleton keeps the last error forever — the paywall clears it on
    // appear so a days-old failure isn't shown for an unrelated tool.
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Purchase

    func purchase(plan: ProPlan = .annual) async {
        await purchase(productID: plan.productID)
    }

    func purchaseSpinOffer() async {
        await purchase(productID: Self.spinOfferProductID)
    }

    private func purchase(productID: String) async {
        // Reentrancy guard — a double-tap landing before the first publish
        // would spawn two StoreKit purchases and flicker purchaseInProgress.
        let alreadyRunning = await MainActor.run { () -> Bool in
            if purchaseInProgress { return true }
            purchaseInProgress = true
            errorMessage = nil
            return false
        }
        guard !alreadyRunning else { return }
        defer { Task { @MainActor in self.purchaseInProgress = false } }

        // Products may have failed to load at launch (offline) — retry once
        // before giving up so recovered connectivity doesn't require a relaunch.
        // Read loadedProducts on the main actor (it's written there).
        if await MainActor.run(body: { loadedProducts[productID] == nil }) {
            await loadProducts()
        }
        guard let product = await MainActor.run(body: { loadedProducts[productID] }) else {
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

    func refreshEntitlements() async {
        let proIDs = Self.allProProductIDs
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
        if UserDefaults.standard.bool(forKey: "debugForceFree") { entitled = false }
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
            let proIDs = Self.allProProductIDs
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
