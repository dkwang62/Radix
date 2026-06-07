import SwiftUI

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
    }

    var paywallBackground: some View {
        RadixTheme.groupedBackground
    }
}
