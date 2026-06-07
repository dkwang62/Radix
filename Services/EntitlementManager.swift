import SwiftUI
import Combine

#if canImport(StoreKit)
import StoreKit
#endif

struct RadixStoreProduct: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String

    #if canImport(StoreKit)
    fileprivate let storeKitProduct: Product

    init(product: Product) {
        self.id = product.id
        self.displayName = product.displayName
        self.description = product.description
        self.displayPrice = product.displayPrice
        self.storeKitProduct = product
    }
    #endif
}

/// Manages paid access. Current policy: 100 free Camera/Text pages; Radix Plus unlocks unlimited pages, import tools, snapshots, and backup; Advanced Pro unlocks exports.
@MainActor
class EntitlementManager: ObservableObject {
    static let datedCopiesProductID = "com.radix.datedcopies"
    static let myBackupProductID = "com.radix.pro.annual"
    static let advancedProductID = "com.radix.pro.lifetime"
    static let annualProductID = myBackupProductID
    static let lifetimeProductID = advancedProductID
    #if DEBUG
    private static let debugOverrideKey = "com.radix.debugProOverride"
    #endif

    enum FeatureGate: String {
        case lineage = "Roots"
        case favourites = "Favourites"
        case datedCopies = "Radix Plus"
        case myBackup = "Radix Plus Backup"
        case advanced = "Advanced Pro"
        case dataEdit = "Data Editing"
        case aiLink = "AI Link"
        case profileTransfer = "Profile Transfer"
    }

    @Published private(set) var products: [RadixStoreProduct] = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var hasDatedCopiesAccess: Bool = false
    @Published private(set) var hasActiveAnnualSubscription: Bool = false
    @Published private(set) var hasLifetimeAccess: Bool = false
    private let preferences: RadixPreferences
    
    @Published var isPro: Bool = false {
        didSet {
            preferences.set(isPro, forKey: Self.isProKey)
        }
    }

    #if DEBUG
    @Published var debugProOverrideEnabled: Bool {
        didSet {
            preferences.set(debugProOverrideEnabled, forKey: Self.debugOverrideKey)
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
    private static let isProKey = "com.radix.isPro"

    init(preferences: RadixPreferences = .standard) {
        self.preferences = preferences
        self.isPro = preferences.bool(forKey: Self.isProKey)
        #if DEBUG
        self.debugProOverrideEnabled = preferences.bool(forKey: Self.debugOverrideKey)
        #endif
        
        #if canImport(StoreKit)
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(transaction: result)
            }
        }
        #endif
        
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
        #if canImport(StoreKit)
        do {
            let identifiers: Set<String> = [Self.myBackupProductID, Self.advancedProductID]
            let loadedProducts = try await Product.products(for: identifiers)
            self.products = loadedProducts
                .sorted(by: productSortPredicate)
                .map(RadixStoreProduct.init(product:))
            self.lastError = nil
        } catch {
            lastError = "Could not load products: \(error.localizedDescription)"
        }
        #else
        products = []
        lastError = "Purchases are unavailable on this platform."
        #endif
    }

    func purchase(_ product: RadixStoreProduct) async -> Bool {
        #if canImport(StoreKit)
        do {
            let result = try await product.storeKitProduct.purchase()
            switch result {
            case .success(let verification):
                await handle(transaction: verification)
                return !requiresPro(featureGate(for: product.id))
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
        #else
        lastError = "Purchases are unavailable on this platform."
        return false
        #endif
    }

    func restorePurchases() async {
        #if canImport(StoreKit)
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastError = nil
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
        #else
        lastError = "Purchases are unavailable on this platform."
        #endif
    }

    #if canImport(StoreKit)
    private func handle(transaction verification: VerificationResult<StoreKit.Transaction>) async {
        switch verification {
        case .verified(let transaction):
            await refreshEntitlements()
            await transaction.finish()
        case .unverified:
            break
        }
    }
    #endif

    // MARK: - Feature Gates

    func requiresPro(_ feature: FeatureGate) -> Bool {
        #if DEBUG
        if debugProOverrideEnabled { return false }
        #endif

        switch feature {
        case .datedCopies:
            return !(hasActiveAnnualSubscription || hasLifetimeAccess || isPro)
        case .myBackup, .profileTransfer:
            return !(hasActiveAnnualSubscription || hasLifetimeAccess || isPro)
        case .advanced, .dataEdit:
            return !hasLifetimeAccess
        case .lineage, .favourites, .aiLink:
            return false
        }
    }
    
    func limitLineage(_ items: [ComponentItem]) -> [ComponentItem] {
        items
    }

    #if DEBUG
    func setDebugProOverride(_ enabled: Bool) {
        debugProOverrideEnabled = enabled
    }
    #endif

    private func refreshEntitlements() async {
        var datedCopies = false
        var annual = false
        var lifetime = false

        #if canImport(StoreKit)
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            switch transaction.productID {
            case Self.datedCopiesProductID:
                datedCopies = true
            case Self.myBackupProductID:
                annual = true
            case Self.advancedProductID:
                lifetime = true
            default:
                break
            }
        }
        #endif

        hasDatedCopiesAccess = datedCopies
        hasActiveAnnualSubscription = annual
        hasLifetimeAccess = lifetime
        isPro = annual || lifetime
    }

    private func featureGate(for productID: String) -> FeatureGate {
        switch productID {
        case Self.myBackupProductID:
            return .datedCopies
        case Self.advancedProductID:
            return .advanced
        default:
            return .advanced
        }
    }

    #if canImport(StoreKit)
    private func productSortPredicate(_ lhs: Product, _ rhs: Product) -> Bool {
        rank(for: lhs.id) < rank(for: rhs.id)
    }
    #endif

    private func rank(for productID: String) -> Int {
        switch productID {
        case Self.myBackupProductID: return 0
        case Self.advancedProductID: return 2
        default: return 99
        }
    }
}
