import SwiftUI

extension CharacterInfoCard {
    var componentGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: componentTileSize, maximum: componentTileSize), spacing: 6)]
    }

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
        "\(item.usageCount)"
    }

    func tierChip(for tier: Int) -> some View {
        Text("Tier \(tier)")
            .font(ResponsiveFont.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func chip(_ text: String) -> some View {
        Text(text)
            .font(chipFont)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
