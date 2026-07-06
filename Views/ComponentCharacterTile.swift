import SwiftUI

struct ComponentCharacterTile: View {
    let item: ComponentItem
    var isCompact = false
    let onTap: () -> Void

    private var isIPad: Bool {
        RadixPlatform.interfaceIdiom == .tablet
    }

    var body: some View {
        VStack(spacing: isCompact ? 1 : 4) {
            Text(item.character)
                .font(.system(size: isCompact ? 24 : 30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(item.pinyinText.isEmpty ? "-" : item.pinyinText)
                .font(pinyinFont)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text("\(item.usageCount)")
                .font(countFont)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(isCompact ? 4 : 8)
        .frame(minWidth: isCompact ? 48 : nil, minHeight: isCompact ? 56 : nil)
        .radixSurface(RadixTheme.background, border: RadixTheme.separator, borderWidth: 0.5)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onTap)
        .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
    }

    private var pinyinFont: Font {
        if isCompact {
            return ResponsiveFont.caption2
        }
        return isIPad ? .system(size: 16, weight: .semibold) : ResponsiveFont.caption
    }

    private var countFont: Font {
        if isCompact {
            return ResponsiveFont.caption2
        }
        return isIPad ? .system(size: 13, weight: .semibold) : ResponsiveFont.caption2
    }
}
