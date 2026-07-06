import SwiftUI

extension SmartSearchTab {
    func setSearchDrilldownAnchor(_ character: String) {
        searchPreviewCharacter = character
        searchDetailPreviewCharacter = character
        searchDrilldownPhrases = store.phraseMatches(for: character, length: store.phraseLength)
    }

    var initialPhraseMatchesForSelectedLength: [PhraseItem] {
        store.filteredSmartPhraseResults.filter(store.phraseMatchesActiveLength)
    }

    var phraseLengthPicker: some View {
        HStack {
            PhraseLengthFilterChips(selection: store.phraseLengthBinding)
            Spacer()
        }
    }

    @ViewBuilder
    func phraseDrilldown(proxy: ScrollViewProxy) -> some View {
        if let current = searchPreviewCharacter,
           store.item(for: current) != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Matching Phrases")
                    .font(ResponsiveFont.headline)
                Text("Select a character above to see matching phrases. Selecting a character inside a phrase only changes the preview.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                phraseLengthPicker

                if searchDrilldownPhrases.isEmpty {
                    emptyPhraseMessage("No \(store.activePhraseLengthFilterLabel)-length phrase matches are available yet for \(current).")
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(searchDrilldownPhrases.prefix(30)) { phrase in
                            phraseResultRow(phrase, proxy: proxy)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func initialPhraseMatches(proxy: ScrollViewProxy) -> some View {
        if searchPreviewCharacter == nil && !store.filteredSmartPhraseResults.isEmpty {
            Divider().padding(.vertical, 8)
            Text("Phrase Matches")
                .font(ResponsiveFont.headline)
            phraseLengthPicker
            if initialPhraseMatchesForSelectedLength.isEmpty {
                emptyPhraseMessage("No \(store.activePhraseLengthFilterLabel)-length phrase matches for this search.")
            }
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(initialPhraseMatchesForSelectedLength.prefix(50)) { phrase in
                    phraseResultRow(phrase, proxy: proxy)
                }
            }
        }
    }

    func emptyPhraseMessage(_ message: String) -> some View {
        Text(message)
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .radixSurface(RadixTheme.secondaryBackground, radius: 10)
    }

    func phraseResultRow(_ phrase: PhraseItem, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phrase.word)
                .font(ResponsiveFont.title3)
                .phraseContextMenu(phrase)
            if !phrase.pinyin.isEmpty {
                Text(phrase.pinyin)
                    .font(ResponsiveFont.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !phrase.meanings.isEmpty {
                Text(phrase.meanings)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(phrase.notes)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            phraseCharacterButtons(phrase, proxy: proxy)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .radixSurface(RadixTheme.secondaryBackground, radius: 10)
        .contentShape(Rectangle())
        .onTapGesture {
            presentPhrase(phrase)
        }
    }

    @ViewBuilder
    func phraseCharacterButtons(_ phrase: PhraseItem, proxy: ScrollViewProxy) -> some View {
        let chars = phrase.word.map(String.init).filter { store.item(for: $0) != nil }
        if !chars.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                        Button(ch) {
                            searchDetailPreviewCharacter = ch
                            store.preview(character: ch)
                            withAnimation { proxy.scrollTo("searchTop", anchor: .top) }
                        }
                        .copyCharacterContextMenu(ch, pinyin: store.item(for: ch)?.pinyinText)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(ResponsiveFont.body)
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}
