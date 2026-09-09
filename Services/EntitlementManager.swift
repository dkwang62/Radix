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

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
        case failed(String)
        case busy
    }

    enum RestoreOutcome: Equatable {
        case restored
        case noPurchases
        case failed(String)
        case busy
    }

    @Published private(set) var products: [RadixStoreProduct] = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var activePurchaseProductID: String? = nil
    @Published private(set) var isRestoringPurchases: Bool = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var hasDatedCopiesAccess: Bool = false
    @Published private(set) var hasActiveAnnualSubscription: Bool = false
    @Published private(set) var hasLifetimeAccess: Bool = false
    private let preferences: any RadixPreferenceStore
    
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

    init(preferences: any RadixPreferenceStore = RadixPreferences.standard) {
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
        guard !isLoadingProducts else { return }
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

    func purchase(_ product: RadixStoreProduct) async -> PurchaseOutcome {
        guard activePurchaseProductID == nil, !isRestoringPurchases else {
            return .busy
        }
        activePurchaseProductID = product.id
        lastError = nil
        defer { activePurchaseProductID = nil }

        #if canImport(StoreKit)
        do {
            let result = try await product.storeKitProduct.purchase()
            switch result {
            case .success(let verification):
                guard case .verified = verification else {
                    let message = "The App Store could not verify this purchase."
                    lastError = message
                    return .failed(message)
                }
                await handle(transaction: verification)
                return requiresPro(featureGate(for: product.id))
                    ? .failed("The purchase completed, but access has not updated yet. Try Restore Purchases.")
                    : .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                let message = "The App Store returned an unknown purchase result."
                lastError = message
                return .failed(message)
            }
        } catch {
            let message = "Purchase failed: \(error.localizedDescription)"
            lastError = message
            return .failed(message)
        }
        #else
        let message = "Purchases are unavailable on this platform."
        lastError = message
        return .failed(message)
        #endif
    }

    func restorePurchases() async -> RestoreOutcome {
        guard activePurchaseProductID == nil, !isRestoringPurchases else {
            return .busy
        }
        isRestoringPurchases = true
        lastError = nil
        defer { isRestoringPurchases = false }

        #if canImport(StoreKit)
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastError = nil
            return (hasDatedCopiesAccess || hasActiveAnnualSubscription || hasLifetimeAccess)
                ? .restored
                : .noPurchases
        } catch {
            let message = "Restore failed: \(error.localizedDescription)"
            lastError = message
            return .failed(message)
        }
        #else
        let message = "Purchases are unavailable on this platform."
        lastError = message
        return .failed(message)
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
