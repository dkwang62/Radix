import SwiftUI
import StoreKit

extension PaywallView {
    var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your plan")
                .font(ResponsiveFont.headline)

            if entitlement.isLoadingProducts {
                ProgressView("Loading plans...")
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

    func planCard(_ product: Product) -> some View {
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

    func productTitle(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "Radix Pro Annual"
        case EntitlementManager.lifetimeProductID:
            return "Radix Pro Lifetime"
        default:
            return product.displayName
        }
    }

    func productSubtitle(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "Start with a 15-day free trial, then continue with full Pro access."
        case EntitlementManager.lifetimeProductID:
            return "One purchase for permanent Pro access."
        default:
            return product.description
        }
    }

    func productPriceLabel(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "\(product.displayPrice)/year"
        default:
            return product.displayPrice
        }
    }

    func productCallToAction(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.annualProductID:
            return "Start 15-Day Free Trial"
        case EntitlementManager.lifetimeProductID:
            return "Unlock Lifetime"
        default:
            return "Continue"
        }
    }

    func badge(_ text: String, emphasized: Bool = false) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(emphasized ? Color.accentColor.opacity(0.14) : Color.orange.opacity(0.14))
            .foregroundStyle(emphasized ? Color.accentColor : Color.orange)
            .clipShape(Capsule())
    }
}
