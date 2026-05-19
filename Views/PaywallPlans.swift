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
        let isDatedCopies = product.id == EntitlementManager.datedCopiesProductID

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
                                badge(planBadgeText(product), emphasized: isMyBackup || isDatedCopies)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(productTitle(product))
                                    .font(ResponsiveFont.subheadline.bold())
                                    .foregroundStyle(.primary)
                                badge(planBadgeText(product), emphasized: isMyBackup || isDatedCopies)
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
                            if isDatedCopies {
                                Text("This device")
                                    .font(ResponsiveFont.caption2)
                                    .foregroundStyle(.secondary)
                            } else if isMyBackup {
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
                    Image(systemName: productActionIcon(product))
                        .font(.system(size: 20))
                }
                .foregroundStyle(isMyBackup || isDatedCopies ? .white : Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isMyBackup || isDatedCopies ? Color.accentColor : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isMyBackup || isDatedCopies ? Color.accentColor.opacity(0.07) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isMyBackup || isDatedCopies ? Color.accentColor.opacity(0.35) : Color(.separator), lineWidth: isMyBackup || isDatedCopies ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    func productTitle(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "Dated Copies"
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
        case EntitlementManager.datedCopiesProductID:
            return "Save and restore dated copies of your Radix memory on this device."
        case EntitlementManager.myBackupProductID:
            return "Dated Copies plus moving your characters, phrases, pages, favorites, settings, and AI Link templates across iPhone, iPad, and Mac."
        case EntitlementManager.advancedProductID:
            return "Developer exports plus Dated Copies and My Backup: datasets, databases, project source, and manifests."
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
        case EntitlementManager.datedCopiesProductID:
            return "Unlock Dated Copies"
        case EntitlementManager.myBackupProductID:
            return "Unlock My Backup"
        case EntitlementManager.advancedProductID:
            return "Unlock Advanced"
        default:
            return "Continue"
        }
    }

    func featureGate(for product: Product) -> EntitlementManager.FeatureGate {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return .datedCopies
        case EntitlementManager.myBackupProductID:
            return .myBackup
        default:
            return .advanced
        }
    }

    func planBadgeText(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "$9"
        case EntitlementManager.myBackupProductID:
            return "$19"
        default:
            return "$99"
        }
    }

    func productActionIcon(_ product: Product) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "clock.badge.checkmark"
        case EntitlementManager.myBackupProductID:
            return "externaldrive.fill"
        default:
            return "star.circle.fill"
        }
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
