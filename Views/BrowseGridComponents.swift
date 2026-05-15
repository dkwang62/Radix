import SwiftUI

struct BrowseGridTileLabel: View {
    let displayCharacter: String
    let pinyin: String
    let fontSize: CGFloat
    let isFavorite: Bool
    let background: Color
    let stroke: Color
    var strokeWidth: CGFloat = 2
    var onShowPhrases: (() -> Void)?

    var body: some View {
        VStack(spacing: 2) {
            Text(displayCharacter)
                .font(.system(size: fontSize))
                .copyCharacterContextMenu(displayCharacter, pinyin: pinyin, onShowPhrases: onShowPhrases)
            Text(pinyin.isEmpty ? " " : pinyin)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(stroke, lineWidth: strokeWidth))
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .padding(6)
            }
        }
    }
}

struct DictionaryGridFooter: View {
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let pageCount: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    private var rangeStart: Int {
        totalCount == 0 ? 0 : page * pageSize + 1
    }

    private var rangeEnd: Int {
        min((page + 1) * pageSize, totalCount)
    }

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(page == 0)
            .accessibilityLabel("Previous page")

            Text("\(rangeStart)–\(rangeEnd) of \(totalCount)")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(page + 1 >= pageCount)
            .accessibilityLabel("Next page")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

enum BrowseImageTileStyle {
    static func background(isActive: Bool, highlightRole: ImagePhraseHighlightRole?, isMemoryHighlighted: Bool) -> Color {
        switch highlightRole {
        case .target:
            return Color.accentColor.opacity(0.24)
        case .phraseMember:
            return Color.blue.opacity(0.16)
        case nil:
            if isMemoryHighlighted {
                return Color.accentColor.opacity(0.18)
            }
            return isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground)
        }
    }

    static func stroke(isActive: Bool, highlightRole: ImagePhraseHighlightRole?, isMemoryHighlighted: Bool) -> Color {
        switch highlightRole {
        case .target:
            return Color.accentColor
        case .phraseMember:
            return Color.blue.opacity(0.72)
        case nil:
            if isMemoryHighlighted {
                return Color.accentColor
            }
            return isActive ? Color.accentColor : Color.clear
        }
    }
}
