import SwiftUI
import Combine
import StoreKit

/// Manages the user's "Pro" status and enforces feature limits using StoreKit 2.
@MainActor
class EntitlementManager: ObservableObject {
    static let annualProductID = "com.radix.pro.annual"
    static let lifetimeProductID = "com.radix.pro.lifetime"
    #if DEBUG
    private static let debugOverrideKey = "com.radix.debugProOverride"
    #endif

    enum FeatureGate: String {
        case lineage = "Roots"
        case favourites = "Favourites"
        case dataEdit = "Data Editor"
        case aiLink = "AI Link"
        case profileTransfer = "Profile Transfer"
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var hasActiveAnnualSubscription: Bool = false
    @Published private(set) var hasLifetimeAccess: Bool = false
    
    @Published var isPro: Bool = false {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "com.radix.isPro")
        }
    }

    #if DEBUG
    @Published var debugProOverrideEnabled: Bool = UserDefaults.standard.bool(forKey: "com.radix.debugProOverride") {
        didSet {
            UserDefaults.standard.set(debugProOverrideEnabled, forKey: Self.debugOverrideKey)
        }
    }
    #endif
    
    var isProUnlocked: Bool {
        #if DEBUG
        return isPro || debugProOverrideEnabled
        #else
        return isPro
        #endif
    }

    private var updatesTask: Task<Void, Never>?

    init() {
        self.isPro = UserDefaults.standard.bool(forKey: "com.radix.isPro")
        
        // Listen for transaction updates
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(transaction: result)
            }
        }
        
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.loadProducts()
        }
    }

    deinit {
        // Task cancellation must be handled carefully in MainActor deinit
        let task = updatesTask
        Task.detached {
            task?.cancel()
        }
    }

    // MARK: - App Store logic

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let identifiers: Set<String> = [Self.annualProductID, Self.lifetimeProductID]
            let loadedProducts = try await Product.products(for: identifiers)
            self.products = loadedProducts.sorted(by: productSortPredicate)
            self.lastError = nil
        } catch {
            lastError = "Could not load products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transaction: verification)
                return isPro
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastError = nil
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func handle(transaction verification: VerificationResult<StoreKit.Transaction>) async {
        switch verification {
        case .verified(let transaction):
            await refreshEntitlements()
            await transaction.finish()
        case .unverified:
            break
        }
    }

    // MARK: - Feature Gates

    func requiresPro(_ feature: FeatureGate) -> Bool {
        if isProUnlocked { return false }
        return true
    }
    
    func limitLineage(_ items: [ComponentItem]) -> [ComponentItem] {
        if isProUnlocked { return items }
        return Array(items.prefix(20))
    }

    #if DEBUG
    func setDebugProOverride(_ enabled: Bool) {
        debugProOverrideEnabled = enabled
    }
    #endif

    private func refreshEntitlements() async {
        var annual = false
        var lifetime = false

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            switch transaction.productID {
            case Self.annualProductID:
                annual = true
            case Self.lifetimeProductID:
                lifetime = true
            default:
                break
            }
        }

        hasActiveAnnualSubscription = annual
        hasLifetimeAccess = lifetime
        isPro = annual || lifetime
    }

    private func productSortPredicate(_ lhs: Product, _ rhs: Product) -> Bool {
        rank(for: lhs.id) < rank(for: rhs.id)
    }

    private func rank(for productID: String) -> Int {
        switch productID {
        case Self.annualProductID: return 0
        case Self.lifetimeProductID: return 1
        default: return 99
        }
    }
}
