import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.dismiss) private var dismiss

    let featureName: String
    @State private var purchasingID: String?

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

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
                Text("Radix Pro")
                    .font(ResponsiveFont.title.bold())
            }

            Text("Advanced tools for serious learners")
                .font(ResponsiveFont.title3.bold())

            Text("Unlock \(featureName), save your work, and turn Radix into a long-term study system.")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                heroChip("15-day free trial")
                heroChip("$25/year")
                heroChip("$99 lifetime")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color.accentColor.opacity(0.05),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
        )
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Pro unlocks")
                .font(ResponsiveFont.headline)

            VStack(alignment: .leading, spacing: 12) {
                benefit("AI-powered study workflows")
                benefit("Character and phrase data editing")
                benefit("Cross-platform data portability")
                benefit("Backup and restore across devices")
                benefit("Future Pro features included")
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your plan")
                .font(ResponsiveFont.headline)

            if entitlement.isLoadingProducts {
                ProgressView("Loading plans…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else if entitlement.products.isEmpty {
                Text("Plans are not available right now. Please try again later.")
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 12) {
                    ForEach(entitlement.products, id: \.id) { product in
                        planCard(product)
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Restore Purchases") {
                Task { await entitlement.restorePurchases() }
            }
            .buttonStyle(.bordered)

            #if DEBUG
            Toggle("Development Pro Access", isOn: Binding(
                get: { entitlement.debugProOverrideEnabled },
                set: { enabled in
                    entitlement.setDebugProOverride(enabled)
                    if enabled {
                        dismiss()
                    }
                }
            ))
            .toggleStyle(.switch)
            #endif

            if let error = entitlement.lastError, !error.isEmpty {
                Text(error)
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.red)
            }

            Text("Annual renews automatically unless canceled at least 24 hours before renewal.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isAnnual = product.id == EntitlementManager.annualProductID

        return Button {
            Task {
                purchasingID = product.id
                _ = await entitlement.purchase(product)
                purchasingID = nil
                if entitlement.isProUnlocked {
                    dismiss()
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(productTitle(product))
                                .font(ResponsiveFont.subheadline.bold())
                                .foregroundStyle(.primary)
                            badge(isAnnual ? "15-day free trial" : "Best for long-term learners", emphasized: isAnnual)
                        }
                        Text(productSubtitle(product))
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if purchasingID == product.id {
                        ProgressView()
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(productPriceLabel(product))
                                .font(ResponsiveFont.subheadline.bold())
                                .foregroundStyle(.primary)
                            if isAnnual {
                                Text("After free trial")
                                    .font(ResponsiveFont.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("One-time purchase")
                                    .font(ResponsiveFont.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                HStack {
                    Text(productCallToAction(product))
                        .font(ResponsiveFont.body.weight(.semibold))
                    Spacer()
                    Image(systemName: isAnnual ? "arrow.right.circle.fill" : "star.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundStyle(isAnnual ? .white : Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isAnnual ? Color.accentColor : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isAnnual ? Color.accentColor.opacity(0.07) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isAnnual ? Color.accentColor.opacity(0.35) : Color(.separator), lineWidth: isAnnual ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(ResponsiveFont.body)
        }
    }

    private func productTitle(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "Radix Pro Annual"
        case EntitlementManager.lifetimeProductID:
            return "Radix Pro Lifetime"
        default:
            return product.displayName
        }
    }

    private func productSubtitle(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "Start with a 15-day free trial, then continue with full Pro access."
        case EntitlementManager.lifetimeProductID:
            return "One purchase for permanent Pro access."
        default:
            return product.description
        }
    }

    private func productPriceLabel(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "\(product.displayPrice)/year"
        default:
            return product.displayPrice
        }
    }

    private func productCallToAction(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "Start 15-Day Free Trial"
        case EntitlementManager.lifetimeProductID:
            return "Unlock Lifetime"
        default:
            return "Continue"
        }
    }

    private func badge(_ text: String, emphasized: Bool = false) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(emphasized ? Color.accentColor.opacity(0.14) : Color.orange.opacity(0.14))
            .foregroundStyle(emphasized ? Color.accentColor : Color.orange)
            .clipShape(Capsule())
    }

    private func heroChip(_ text: String) -> some View {
        Text(text)
            .font(ResponsiveFont.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemBackground).opacity(0.8))
            .clipShape(Capsule())
    }

    private var paywallBackground: some View {
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
