import SwiftUI

extension PhraseInfoCard {
    var phraseHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(phrase.word)
                    .font(.system(size: 32, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.32)
                    .allowsTightening(true)
                    .layoutPriority(1)
                    .phraseContextMenu(phrase)

                phrasePinyinRow
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                favoriteTargetButton

                if !isEditingNotes {
                    editNotesButton
                }
            }
        }
    }

    var editNotesButton: some View {
        Button {
            editableNotes = phrase.notes
            editStatus = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingNotes = true
            }
        } label: {
            Image(systemName: "square.and.pencil")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .radixIconButtonSurface(size: 32)
        }
        .buttonStyle(.plain)
        .help("Edit notes")
    }

    @ViewBuilder
    var favoriteTargetButton: some View {
        switch favoriteTarget {
        case .sentence(let practiceItem):
            Button {
                store.toggleFavoriteSentence(practiceItem)
            } label: {
                Image(systemName: store.isFavoriteSentence(practiceItem) ? "star.fill" : "star")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(store.isFavoriteSentence(practiceItem) ? .yellow : .secondary)
                    .radixIconButtonSurface()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isFavoriteSentence(practiceItem) ? "Remove sentence from favorites" : "Add sentence to favorites")
            .help(store.isFavoriteSentence(practiceItem) ? "Remove sentence from favorites" : "Add sentence to favorites")
        case .phrase:
            Button {
                store.togglePhraseFavorite(phrase.word)
            } label: {
                Image(systemName: store.isPhraseFavorite(phrase.word) ? "star.fill" : "star")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(store.isPhraseFavorite(phrase.word) ? .yellow : .secondary)
                    .radixIconButtonSurface()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isPhraseFavorite(phrase.word) ? "Remove from favorites" : "Add to favorites")
            .help(store.isPhraseFavorite(phrase.word) ? "Remove from favorites" : "Add to favorites")
        }
    }

    var phrasePinyinRow: some View {
        HStack(alignment: .top, spacing: 8) {
            let trimmedPinyin = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPinyin.isEmpty {
                Text(trimmedPinyin)
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)
        }
    }

}
