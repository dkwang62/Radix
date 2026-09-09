import SwiftUI

extension PhraseInfoCard {
    var phraseHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(phrase.word)
                    .font(ResponsiveFont.title.weight(.bold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .layoutPriority(1)
                    .phraseContextMenu(phrase)

                phrasePinyinRow
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                phraseSentenceReturnButton
                phraseLibraryActionButton
                favoriteTargetButton

                if !isEditingNotes {
                    editNotesButton
                }
            }
        }
    }

    @ViewBuilder
    var phraseSentenceReturnButton: some View {
        if !isPracticeSentence, store.sidebarSentenceReturnPhrase != nil {
            Button {
                store.returnToPracticeSentenceInSidebar()
            } label: {
                InfoCardActionPill(
                    title: "Sentence",
                    systemImage: "chevron.left",
                    verticalPadding: 8
                )
            }
            .buttonStyle(.plain)
            .radixMinimumTapTarget()
            .help("Back to sentence")
        }
    }

    @ViewBuilder
    var phraseLibraryActionButton: some View {
        if !isPracticeSentence, canDeleteAddedPhrase {
            Button(role: .destructive) {
                showDeletePhraseConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .radixIconButtonSurface()
            }
            .buttonStyle(.plain)
            .radixMinimumTapTarget()
            .accessibilityLabel("Delete phrase")
            .help("Delete phrase")
        }
    }

    var editNotesButton: some View {
        Button {
            editableNotes = committedNotes
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
        .radixMinimumTapTarget()
        .help("Edit notes")
    }

    @ViewBuilder
    var favoriteTargetButton: some View {
        switch favoriteTarget {
        case .sentence:
            if let practiceItem = practiceSentenceItem {
                Button {
                    do {
                        try store.toggleFavoriteSentence(practiceItem)
                        editStatus = store.isFavoriteSentence(practiceItem) ? "Favorited." : "Removed favorite."
                    } catch {
                        editStatus = "Favorite failed: \(error.localizedDescription)"
                    }
                } label: {
                    Image(systemName: store.isFavoriteSentence(practiceItem) ? "star.fill" : "star")
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                        .foregroundStyle(store.isFavoriteSentence(practiceItem) ? .yellow : .secondary)
                        .radixIconButtonSurface()
                }
                .buttonStyle(.plain)
                .radixMinimumTapTarget()
                .accessibilityLabel(store.isFavoriteSentence(practiceItem) ? "Remove sentence from favorites" : "Add sentence to favorites")
                .help(store.isFavoriteSentence(practiceItem) ? "Remove sentence from favorites" : "Add sentence to favorites")
            }
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
            .radixMinimumTapTarget()
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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)
        }
    }

}
