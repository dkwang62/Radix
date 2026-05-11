import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.dismiss) var dismiss

    let featureName: String
    @State var purchasingID: String?

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
            .navigationTitle("Radix Pro")
            .background(paywallBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    var paywallBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color.accentColor.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
