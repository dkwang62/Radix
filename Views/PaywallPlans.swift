import SwiftUI

extension PaywallView {
    var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your plan")
                .font(ResponsiveFont.headline)

            if entitlement.isLoadingProducts {
                ProgressView("Loading plans...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .background(RadixTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if entitlement.products.isEmpty {
                Label("Plans are not available right now. Please try again later.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RadixTheme.secondaryBackground)
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

    func planCard(_ product: RadixStoreProduct) -> some View {
        let isRadixPlus = product.id == EntitlementManager.myBackupProductID || product.id == EntitlementManager.datedCopiesProductID

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
                                badge(planBadgeText(product), emphasized: isRadixPlus)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(productTitle(product))
                                    .font(ResponsiveFont.subheadline.bold())
                                    .foregroundStyle(.primary)
                                badge(planBadgeText(product), emphasized: isRadixPlus)
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
                            if isRadixPlus {
                                Text("Annual")
                                    .font(ResponsiveFont.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Lifetime")
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
                .foregroundStyle(isRadixPlus ? .white : Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isRadixPlus ? Color.accentColor : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isRadixPlus ? Color.accentColor.opacity(0.07) : RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRadixPlus ? Color.accentColor.opacity(0.35) : RadixTheme.separator, lineWidth: isRadixPlus ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    func productTitle(_ product: RadixStoreProduct) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "Radix Plus"
        case EntitlementManager.myBackupProductID:
            return "Radix Plus"
        case EntitlementManager.advancedProductID:
            return "Advanced Pro"
        default:
            return product.displayName
        }
    }

    func productSubtitle(_ product: RadixStoreProduct) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "Create pages from Album, Files, or pasted text, plus save and restore local snapshots on this device."
        case EntitlementManager.myBackupProductID:
            return "Unlimited Camera/Text pages, Album/File import, local snapshots, and iCloud backup across iPhone, iPad, and Mac."
        case EntitlementManager.advancedProductID:
            return "Everything in Radix Plus, plus developer exports: datasets, databases, project source, and manifests."
        default:
            return product.description
        }
    }

    func productPriceLabel(_ product: RadixStoreProduct) -> String {
        switch product.id {
        case EntitlementManager.myBackupProductID:
            return product.displayPrice
        default:
            return product.displayPrice
        }
    }

    func productCallToAction(_ product: RadixStoreProduct) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "Unlock Radix Plus"
        case EntitlementManager.myBackupProductID:
            return "Start Radix Plus"
        case EntitlementManager.advancedProductID:
            return "Unlock Advanced Pro"
        default:
            return "Continue"
        }
    }

    func featureGate(for product: RadixStoreProduct) -> EntitlementManager.FeatureGate {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return .datedCopies
        case EntitlementManager.myBackupProductID:
            return .datedCopies
        default:
            return .advanced
        }
    }

    func planBadgeText(_ product: RadixStoreProduct) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "Page tools"
        case EntitlementManager.myBackupProductID:
            return "Recommended"
        default:
            return "Advanced Pro"
        }
    }

    func productActionIcon(_ product: RadixStoreProduct) -> String {
        switch product.id {
        case EntitlementManager.datedCopiesProductID:
            return "clock.badge.checkmark"
        case EntitlementManager.myBackupProductID:
            return "camera.viewfinder"
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
