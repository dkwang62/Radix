import SwiftUI

extension PhraseInfoCard {
    var phraseHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(phrase.word)
                .font(.system(size: 28, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .phraseContextMenu(phrase)

            Spacer(minLength: 0)

            Button {
                store.togglePhraseFavorite(phrase.word)
            } label: {
                Image(systemName: store.isPhraseFavorite(phrase.word) ? "star.fill" : "star")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(store.isPhraseFavorite(phrase.word) ? .yellow : .secondary)
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
                        .font(ResponsiveFont.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit notes")
            }
        }
    }

    var phrasePinyinRow: some View {
        HStack(alignment: .center, spacing: 8) {
            let trimmedPinyin = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPinyin.isEmpty {
                Text(trimmedPinyin)
                    .font(ResponsiveFont.headline.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)

            if let onDone {
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator).opacity(0.75), lineWidth: 1)
                )
                .accessibilityLabel("Close")
            }
        }
    }
}
