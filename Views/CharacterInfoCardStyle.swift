import SwiftUI

extension CharacterInfoCard {
    var characterTileSize: CGFloat {
        isPhone ? 64 : 70
    }

    var componentTileSize: CGFloat {
        isPhone ? 48 : 54
    }

    var componentCharacterFontSize: CGFloat {
        isPhone ? 20 : 22
    }

    var usageCountSubtitle: String {
        "\(item.usageCount) char\(item.usageCount == 1 ? "" : "s")"
    }

    var usageCountAccessibilityLabel: String {
        if item.usageCount <= 1 {
            return "\(item.character), not used in other characters"
        }
        return "\(item.character), component used in \(item.usageCount) characters"
    }

    var usageCountAccessibilityHint: String {
        item.usageCount > 1
            ? "Opens related characters that use this component."
            : "Shows component usage information."
    }

    func tierChip(for tier: Int) -> some View {
        Text("Tier \(tier)")
            .font(ResponsiveFont.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .radixPill(horizontal: 8, vertical: 4, background: tierColor)
    }

    func chip(_ text: String) -> some View {
        Text(text)
            .font(chipFont)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .radixPill(horizontal: 10, vertical: 6, background: RadixTheme.secondaryBackground)
    }

    var cardActionFont: Font {
        RadixPlatform.isDesktop
            ? ResponsiveFont.caption2.weight(.semibold)
            : ResponsiveFont.caption.weight(.semibold)
    }

    var cardActionControlSize: ControlSize {
        RadixPlatform.isDesktop ? .small : .regular
    }

    var chipGuideFont: Font {
        RadixPlatform.isDesktop ? ResponsiveFont.footnote : ResponsiveFont.subheadline
    }

    var chipFont: Font {
        if RadixPlatform.isDesktop {
            return ResponsiveFont.footnote.weight(.semibold)
        }
        return isPhone
            ? ResponsiveFont.subheadline.weight(.semibold)
            : ResponsiveFont.footnote.weight(.semibold)
    }
}
