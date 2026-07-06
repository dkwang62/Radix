import SwiftUI

extension PaywallView {
    var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(RadixAccent.primary)
                Text("Upgrade Radix")
                    .font(ResponsiveFont.title.bold())
            }

            Text("Read Chinese around you for free. Upgrade when Radix becomes part of daily life.")
                .font(ResponsiveFont.title3.bold())

            Text("Your first 100 Camera or Text pages are free, and saved items stay reviewable. Radix Plus unlocks unlimited pages, Album/File import, local snapshots, and iCloud backup.")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heroChip("Everything else free")
                    heroChip("100 free pages")
                    heroChip("Radix Plus yearly")
                    heroChip("Advanced Pro")
                }
                VStack(alignment: .leading, spacing: 8) {
                    heroChip("Everything else free")
                    heroChip("100 free pages")
                    heroChip("Radix Plus yearly")
                    heroChip("Advanced Pro")
                }
            }
        }
        .padding(20)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RadixAccent.primary.opacity(0.18), lineWidth: 1)
        )
    }

    var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What unlocks")
                .font(ResponsiveFont.headline)

            VStack(alignment: .leading, spacing: 10) {
                benefit("Free includes 100 Camera or Text pages and unlimited review of saved items")
                benefit("Radix Plus unlocks unlimited pages, Album/File import, and local snapshots")
                benefit("Radix Plus includes iCloud backup across iPhone, iPad, and Mac")
                benefit("Advanced Pro exports source and reusable data foundations for authoring software with AI coding agents")
                benefit("Browse, Search, Study, AI Link, and editing stay free")
            }
        }
        .padding(18)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func benefit(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(ResponsiveFont.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func heroChip(_ text: String) -> some View {
        Text(text)
            .font(ResponsiveFont.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RadixTheme.background.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
