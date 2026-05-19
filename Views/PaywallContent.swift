import SwiftUI

extension PaywallView {
    var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
                Text("Upgrade Radix")
                    .font(ResponsiveFont.title.bold())
            }

            Text("Keep learning for free. Pay when you need local copies or data portability.")
                .font(ResponsiveFont.title3.bold())

            Text("Scan, Browse, Search, Study, AI Link, and editing stay free. Dated Copies saves your memory on this device; My Backup lets it travel to iPad and Mac.")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heroChip("Everything else free")
                    heroChip("Dated Copies $9")
                    heroChip("My Backup $19")
                    heroChip("Advanced $99")
                }
                VStack(alignment: .leading, spacing: 8) {
                    heroChip("Everything else free")
                    heroChip("Dated Copies $9")
                    heroChip("My Backup $19")
                    heroChip("Advanced $99")
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What unlocks")
                .font(ResponsiveFont.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                benefit("Dated Copies saves and restores your Radix memory on this device")
                benefit("My Backup gives your Radix data portability across iPhone, iPad, and Mac")
                benefit("Advanced exports reusable datasets and databases")
                benefit("My Backup and Advanced include Dated Copies")
                benefit("The main learning app stays free")
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
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
            .background(Color(.systemBackground).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
