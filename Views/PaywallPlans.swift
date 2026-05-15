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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if entitlement.products.isEmpty {
                Label("Plans are not available right now. Please try again later.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
        let isMyBackup = product.id == EntitlementManager.myBackupProductID

        return Button {
            Task {
                purchasingID = product.id
                _ = await entitlement.purchase(product)
                purchasingID = nil
                if !entitlement.requiresPro(featureGate(for: product)) {
                    dismiss()
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Text(productTitle(product))
                                    .font(ResponsiveFont.subheadline.bold())
                                    .foregroundStyle(.primary)
                                badge(isMyBackup ? "$19" : "$99", emphasized: isMyBackup)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(productTitle(product))
                                    .font(ResponsiveFont.subheadline.bold())
                                    .foregroundStyle(.primary)
                                badge(isMyBackup ? "$19" : "$99", emphasized: isMyBackup)
                            }
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
                            if isMyBackup {
                                Text("Data portability")
                                    .font(ResponsiveFont.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Includes My Backup")
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
                    Image(systemName: isMyBackup ? "externaldrive.fill" : "star.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundStyle(isMyBackup ? .white : Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isMyBackup ? Color.accentColor : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isMyBackup ? Color.accentColor.opacity(0.07) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isMyBackup ? Color.accentColor.opacity(0.35) : Color(.separator), lineWidth: isMyBackup ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    func productTitle(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.myBackupProductID:
            return "My Backup"
        case EntitlementManager.advancedProductID:
            return "Advanced"
        default:
            return product.displayName
        }
    }

    func productSubtitle(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.myBackupProductID:
            return "Move your characters, phrases, pages, favorites, settings, and AI Link templates across iPhone, iPad, and Mac."
        case EntitlementManager.advancedProductID:
            return "Developer exports plus My Backup: datasets, databases, project source, and manifests."
        default:
            return product.description
        }
    }

    func productPriceLabel(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.myBackupProductID:
            return product.displayPrice
        default:
            return product.displayPrice
        }
    }

    func productCallToAction(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.myBackupProductID:
            return "Unlock My Backup"
        case EntitlementManager.advancedProductID:
            return "Unlock Advanced"
        default:
            return "Continue"
        }
    }

    func featureGate(for product: Product) -> EntitlementManager.FeatureGate {
        product.id == EntitlementManager.myBackupProductID ? .myBackup : .advanced
    }

    func badge(_ text: String, emphasized: Bool = false) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(emphasized ? Color.accentColor.opacity(0.14) : Color.orange.opacity(0.14))
            .foregroundStyle(emphasized ? Color.accentColor : Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
