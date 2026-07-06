import SwiftUI

struct RadixMenuSelectorRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var isMissing = false
    var minHeight: CGFloat = 58
    var titleFont: Font = ResponsiveFont.body.weight(.semibold)

    private var tint: Color {
        isMissing ? .orange : Color.accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .radixSurface(tint.opacity(0.12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(titleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let subtitle {
                    Text(subtitle)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, subtitle == nil ? 0 : 12)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .radixSurface(
            RadixTheme.background,
            border: Color.accentColor.opacity(0.35)
        )
    }
}
