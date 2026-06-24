import Foundation
import Combine

// MARK: - ProManager

final class ProManager: ObservableObject {
    static let shared = ProManager()

    @Published private(set) var isPro: Bool
    @Published private(set) var purchaseInProgress = false
    @Published private(set) var errorMessage: String? = nil

    private let udKey = "pointly_isPro"

    private init() {
        isPro = UserDefaults.standard.bool(forKey: udKey)
    }

    // Tools that require Pro
    static let proTools: Set<DrawingTool> = [.blurBrush, .laserPointer, .spotlight]

    func isLocked(_ tool: DrawingTool) -> Bool {
        !isPro && Self.proTools.contains(tool)
    }

    // MARK: - Purchase (stub — integrate StoreKit 2 / Paddle here)

    func purchase() async {
        await MainActor.run { purchaseInProgress = true; errorMessage = nil }

        // TODO: Replace with real StoreKit 2 purchase
        // let products = try? await Product.products(for: ["com.pointly.pro.lifetime"])
        // let result = try? await products?.first?.purchase()
        // handle result...

        // Simulated 1-second purchase delay for UX testing
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        unlock()

        await MainActor.run { purchaseInProgress = false }
    }

    func restorePurchases() async {
        await MainActor.run { purchaseInProgress = true; errorMessage = nil }

        // TODO: Replace with real StoreKit 2 restore
        // for await result in Transaction.currentEntitlements { ... }

        // For now re-read UserDefaults (persists across launches once unlocked)
        let stored = UserDefaults.standard.bool(forKey: udKey)
        await MainActor.run {
            isPro = stored
            purchaseInProgress = false
            if !stored { errorMessage = "No purchase found for this Apple ID." }
        }
    }

    // Called on success — persists state and publishes change
    func unlock() {
        UserDefaults.standard.set(true, forKey: udKey)
        DispatchQueue.main.async { self.isPro = true }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let showPaywall = Notification.Name("ShowProPaywall")
}
