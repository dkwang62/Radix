import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.dismiss) var dismiss

    let featureName: String
    @State var purchasingID: String?
    @State var pendingPurchaseID: String?
    @State var storeOperationMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    featureSection
                    plansSection
                    footerSection
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Upgrade")
            .background(paywallBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .task {
            if entitlement.products.isEmpty {
                await entitlement.loadProducts()
            }
        }
        .onChange(of: entitlement.hasDatedCopiesAccess) { _, _ in
            finishPendingPurchaseIfUnlocked()
        }
        .onChange(of: entitlement.hasActiveAnnualSubscription) { _, _ in
            finishPendingPurchaseIfUnlocked()
        }
        .onChange(of: entitlement.hasLifetimeAccess) { _, _ in
            finishPendingPurchaseIfUnlocked()
        }
    }

    var storeOperationInProgress: Bool {
        purchasingID != nil || entitlement.isRestoringPurchases || entitlement.isLoadingProducts
    }

    func finishPendingPurchaseIfUnlocked() {
        guard let pendingPurchaseID,
              let product = entitlement.products.first(where: { $0.id == pendingPurchaseID }),
              !entitlement.requiresPro(featureGate(for: product)) else { return }
        self.pendingPurchaseID = nil
        storeOperationMessage = "Purchase approved. Access is now available."
        dismiss()
    }

    var paywallBackground: some View {
        RadixTheme.groupedBackground
    }
}
