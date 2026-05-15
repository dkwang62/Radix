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

            Text("Keep learning for free. Pay when you need data portability.")
                .font(ResponsiveFont.title3.bold())

            Text("Scan, Browse, Search, Study, AI Link, and editing stay free. My Backup lets the work you do on iPhone travel to iPad and Mac.")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heroChip("Everything else free")
                    heroChip("My Backup $19")
                    heroChip("Advanced $99")
                }
                VStack(alignment: .leading, spacing: 8) {
                    heroChip("Everything else free")
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
                benefit("My Backup gives your Radix data portability across iPhone, iPad, and Mac")
                benefit("Advanced exports reusable datasets and databases")
                benefit("Advanced includes My Backup")
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
