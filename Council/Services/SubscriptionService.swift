import Foundation
import RevenueCat
import FirebaseAuth

@MainActor
class SubscriptionService: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = SubscriptionService()

    @Published var isPremium = false
    @Published var currentOffering: Offering?
    @Published var isLoading = false

    private static let apiKey = "appl_kuorOeNOYAowKcWPVeRoEBHxDSt"
    private static let entitlementID = "premium"

    private override init() {
        super.init()
    }

    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.shared.delegate = self
    }

    // MARK: - PurchasesDelegate

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        }
    }

    func login(userId: String) async {
        do {
            let (_, _) = try await Purchases.shared.logIn(userId)
            await refreshStatus()
        } catch {
            print("[SubscriptionService] Login error: \(error.localizedDescription)")
        }
    }

    func logout() async {
        isPremium = false
        do {
            let _ = try await Purchases.shared.logOut()
        } catch {
            print("[SubscriptionService] Logout error: \(error.localizedDescription)")
        }
    }

    func refreshStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            print("[SubscriptionService] Status refresh error: \(error.localizedDescription)")
        }
    }

    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            print("[SubscriptionService] Offerings error: \(error.localizedDescription)")
        }
    }

    func purchase(_ package: Package) async -> Bool {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            isPremium = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
            return isPremium
        } catch {
            print("[SubscriptionService] Purchase error: \(error.localizedDescription)")
            // Purchase may have succeeded on Apple's side — refresh status
            await refreshStatus()
            return isPremium
        }
    }

    func restorePurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            return isPremium
        } catch {
            print("[SubscriptionService] Restore error: \(error.localizedDescription)")
            return false
        }
    }
}
