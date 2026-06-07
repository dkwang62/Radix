import SwiftUI

extension FavouritesTab {
    var favoriteCharacterColumns: [GridItem] {
        let maximum: CGFloat = RadixPlatform.isDesktop ? 82 : (isNarrowStudyLayout ? 72 : 78)
        return [GridItem(.adaptive(minimum: 44, maximum: maximum), spacing: 8)]
    }

    func favoriteCharacterCell(_ item: ComponentItem) -> some View {
        let isActive = item.character == store.previewCharacter

        return Button {
            store.preview(character: item.character)
        } label: {
            VStack(spacing: 2) {
                Text(item.character)
                    .font(.system(size: isPhone ? 28 : 30, weight: .bold))
                    .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                    .font(ResponsiveFont.tinySystem(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.18) : RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
    }

    var favoritePhraseColumns: [GridItem] {
        let maximum: CGFloat = RadixPlatform.isDesktop ? 180 : (isNarrowStudyLayout ? 170 : 180)
        return [GridItem(.adaptive(minimum: 120, maximum: maximum), spacing: 8)]
    }

    func favoritePhraseRow(_ phrase: PhraseItem) -> some View {
        let leadingColumnWidth: CGFloat = RadixPlatform.isDesktop ? 150 : (isPhone ? 96 : 120)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.secondary)
            }
            .frame(width: leadingColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings.isEmpty ? "No meaning" : phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: favoritePhraseRowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            presentPhrase(phrase)
        }
        .phraseContextMenu(phrase)
    }

    var favoritePhraseRowHeight: CGFloat {
        RadixPlatform.isDesktop ? 84 : (isPhone ? 72 : 82)
    }

    var favoritePhraseViewportHeight: CGFloat {
        let visibleRows = min(max(store.favoritePhrasesItems.count, 1), 6)
        return (favoritePhraseRowHeight * CGFloat(visibleRows)) + 5
    }

    func favoriteAddedLabel(for character: String) -> String {
        guard let addedAt = store.favoriteAddedDate(for: character) else {
            return "Saved before dates were tracked"
        }

        let relative = Self.relativeFormatter.localizedString(for: addedAt, relativeTo: Date())
        let absolute = Self.addedDateFormatter.string(from: addedAt)
        return "Added \(relative) (\(absolute))"
    }
}
