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
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var cardActionFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.caption2.weight(.semibold)
        #else
        return ResponsiveFont.caption.weight(.semibold)
        #endif
    }

    var cardActionControlSize: ControlSize {
        #if targetEnvironment(macCatalyst)
        return .small
        #else
        return .regular
        #endif
    }

    var chipGuideFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.footnote
        #else
        return isPhone ? ResponsiveFont.subheadline : ResponsiveFont.subheadline
        #endif
    }

    var chipFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.footnote.weight(.semibold)
        #else
        return isPhone ? ResponsiveFont.subheadline.weight(.semibold) : ResponsiveFont.footnote.weight(.semibold)
        #endif
    }
}
