import SwiftUI

struct RadixChevronRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var isMissing = false
    var minHeight: CGFloat = 58
    var titleFont: Font = ResponsiveFont.body.weight(.semibold)
    var chevronSystemName = "chevron.down"

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

            Image(systemName: chevronSystemName)
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

struct RadixMenuSelectorRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var isMissing = false
    var minHeight: CGFloat = 58
    var titleFont: Font = ResponsiveFont.body.weight(.semibold)

    var body: some View {
        RadixChevronRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            isMissing: isMissing,
            minHeight: minHeight,
            titleFont: titleFont,
            chevronSystemName: "chevron.down"
        )
    }
}

struct RadixCompactChevronLabel: View {
    var title: String? = nil
    var systemImage: String? = nil
    var chevronSystemName = "chevron.down"
    var font: Font = ResponsiveFont.caption2.weight(.semibold)
    var chevronFont: Font = .system(size: 9, weight: .bold)
    var chevronForegroundStyle: Color? = nil
    var spacing: CGFloat = 5
    var minWidth: CGFloat? = nil
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var usesHierarchicalSymbol = false

    var body: some View {
        HStack(spacing: spacing) {
            if let systemImage {
                if usesHierarchicalSymbol {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.hierarchical)
                } else {
                    Image(systemName: systemImage)
                }
            }

            if let title {
                Text(title)
            }

            Group {
                if let chevronForegroundStyle {
                    Image(systemName: chevronSystemName)
                        .font(chevronFont)
                        .foregroundStyle(chevronForegroundStyle)
                } else {
                    Image(systemName: chevronSystemName)
                        .font(chevronFont)
                }
            }
            .opacity(0.75)
        }
        .font(font)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(minWidth: minWidth ?? 0)
        .frame(width: width, height: height)
    }
}
