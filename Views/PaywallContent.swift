import SwiftUI

extension PaywallView {
    var heroSection: some View {
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

    var featureSection: some View {
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

    func benefit(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(ResponsiveFont.body)
        }
    }

    func heroChip(_ text: String) -> some View {
        Text(text)
            .font(ResponsiveFont.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemBackground).opacity(0.8))
            .clipShape(Capsule())
    }
}
