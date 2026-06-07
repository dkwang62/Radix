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
                Button {
                    store.togglePhraseFavorite(phrase.word)
                } label: {
                    Image(systemName: store.isPhraseFavorite(phrase.word) ? "star.fill" : "star")
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                        .foregroundStyle(store.isPhraseFavorite(phrase.word) ? .yellow : .secondary)
                        .frame(width: 32, height: 32)
                        .background(RadixTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help(store.isPhraseFavorite(phrase.word) ? "Remove from favorites" : "Add to favorites")

                if !isEditingNotes {
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
                            .frame(width: 32, height: 32)
                            .background(RadixTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help("Edit notes")
                }
            }
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
