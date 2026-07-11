import SwiftUI

extension FilterGridTab {
    @ViewBuilder
    func imageGridContent(collection: CharacterCollection, proxy: ScrollViewProxy) -> some View {
        let allItems = browseImageGridItems(for: collection)
        let pageFontSize = max(13, fontSize - 1)

        if !isPhoneBrowseLayout {
            browseHintIfNeeded
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }

        RadixTileFlowLayout(horizontalSpacing: RadixTileMetrics.compactSpacing, verticalSpacing: RadixTileMetrics.compactSpacing) {
            ForEach(allItems) { item in
                switch item.kind {
                case .character(let character):
                    let offset = item.offset
                    let displayCharacter = browseImageDisplayCharacter(character)
                    let highlightRole = store.imagePhraseHighlightRole(collectionID: collection.id, offset: offset)
                    let isMemoryHighlighted = store.isBrowseMemoryHighlighted(collectionID: collection.id, offset: offset)
                    let isActive = highlightRole == .target || lastTappedImageOffset == offset
                    let pinyin = store.item(for: character)?.pinyinText ?? ""
                    Button {
                        lastTappedImageOffset = offset
                        // Page phrases are now explicit tiles. Character tiles must preview only
                        // the tapped character so the old neighboring-phrase inference cannot leak in.
                        store.previewImageCharacter(character, offset: offset)
                    } label: {
                        BrowseGridTileLabel(
                            displayCharacter: displayCharacter,
                            pinyin: pinyin,
                            fontSize: pageFontSize,
                            isFavorite: store.isFavorite(character),
                            background: BrowseImageTileStyle.background(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                            stroke: BrowseImageTileStyle.stroke(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                            strokeWidth: highlightRole == nil ? 2 : 2.5
                        ) {
                            store.previewImageCharacter(character, offset: offset, announce: false)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                NotificationCenter.default.post(name: .radixShowPhraseTable, object: character)
                            }
                        }
                        .frame(width: browseGridLayout.tileMaximumWidth)
                    }
                    .buttonStyle(.plain)
                    .id(imageTileAnchorID(offset))

                case .phrase(let phrase, let offsets):
                    let isActive = offsets.contains(lastTappedImageOffset ?? -1)
                    BrowseImagePhraseTile(
                        phraseText: browseImageDisplayText(phrase.word),
                        pinyin: phrase.pinyin,
                        isActive: isActive,
                        fontSize: pageFontSize,
                        contextMenuPhrase: phrase
                    ) {
                        if let offset = offsets.first, collection.characters.indices.contains(offset) {
                            lastTappedImageOffset = offset
                        }
                        store.presentPhraseFromBrowseImageTile(phrase, in: collection, offsets: Set(offsets))
                    }
                    .frame(maxWidth: phraseTileWidth(for: offsets.count))
                    .id(imageTileAnchorID(item.offset))
                }
            }
        }
        .padding(.top, 6)
    }

    func browseImageGridItems(for collection: CharacterCollection) -> [BrowseImageGridItem] {
        let phraseTiles = store.browsePagePhraseTiles(in: collection)
        var items: [BrowseImageGridItem] = []
        var offset = 0

        while offset < collection.characters.count {
            if let phraseTile = phraseTiles[offset] {
                items.append(BrowseImageGridItem(offset: offset, kind: .phrase(phraseTile.phrase, phraseTile.offsets)))
                offset = phraseTile.end
            } else {
                items.append(BrowseImageGridItem(offset: offset, kind: .character(collection.characters[offset])))
                offset += 1
            }
        }

        return items
    }

    func browseImageDisplayCharacter(_ character: String) -> String {
        browseImageDisplayText(character)
    }

    func browseImageDisplayText(_ text: String) -> String {
        useTraditionalBrowseImageScript ? store.traditionalText(text) : store.simplifiedText(text)
    }

    func phraseTileWidth(for characterCount: Int) -> CGFloat {
        let tileWidth = browseGridLayout.tileMaximumWidth
        let spacing = RadixTileMetrics.compactSpacing
        return min(RadixTileMetrics.browsePhraseWidth, tileWidth * CGFloat(max(2, characterCount)) + spacing * CGFloat(max(1, characterCount - 1)))
    }
}

struct BrowseImageGridItem: Identifiable {
    let offset: Int
    let kind: Kind

    var id: String {
        switch kind {
        case .character:
            return "character-\(offset)"
        case .phrase(let phrase, let offsets):
            return "phrase-\(offset)-\(phrase.id)-\(offsets.count)"
        }
    }

    enum Kind {
        case character(String)
        case phrase(PhraseItem, [Int])
    }
}

struct BrowsePagePhraseListSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let collectionID: UUID
    @State private var phrasePendingDeletion: PhraseItem?
    @State private var pagePhraseActionMessage: String?

    private var collection: CharacterCollection? {
        store.collection(id: collectionID)
    }

    private var candidates: [BrowsePagePhraseCandidate] {
        guard let collection else { return [] }
        return store.browsePagePhraseCandidates(in: collection)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let collection {
                    if candidates.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "No page phrases",
                                systemImage: "text.quote",
                                description: Text("Radix did not find any dictionary phrases on this page.")
                            )

                            addNewPagePhraseButton
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            Section {
                                ForEach(candidates) { candidate in
                                    phraseChoiceRow(candidate, collection: collection)
                                }
                            } footer: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hide phrases that do not fit this page context. Hidden here only changes this saved page.")
                                    if let pagePhraseActionMessage {
                                        Text(pagePhraseActionMessage)
                                            .font(ResponsiveFont.caption.weight(.semibold))
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    ContentUnavailableView("Page not found", systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage))
                }
            }
            .navigationTitle("Page Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    addNewPagePhraseButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Delete Phrase?", isPresented: deleteConfirmationBinding) {
            Button("Delete Phrase", role: .destructive) {
                deletePendingPhrase()
            }
            Button("Cancel", role: .cancel) {
                phrasePendingDeletion = nil
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    private func phraseChoiceRow(_ candidate: BrowsePagePhraseCandidate, collection: CharacterCollection) -> some View {
        let word = store.normalizedPhraseWord(candidate.phrase.word)
        let isHidden = collection.hiddenPhraseWords?.contains(word) == true
        let isAdded = store.isPhraseInAdd(word)
        let isBase = store.isPhraseInBase(word)

        return HStack(spacing: 10) {
            PhraseSummaryTile(
                phrase: candidate.phrase,
                minimumHeight: 48,
                maximumWidth: 190,
                onSelect: {
                    store.presentPhraseFromBrowseImageTile(
                        candidate.phrase,
                        in: collection,
                        offsets: store.phraseHighlightOffsets(in: collection, word: candidate.phrase.word)
                    )
                }
            )
            .phraseContextMenu(candidate.phrase)

            pagePhraseLibraryActions(for: candidate.phrase, isAdded: isAdded, isBase: isBase)

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.occurrenceCount == 1 ? "1 place" : "\(candidate.occurrenceCount) places")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Toggle(isOn: Binding(
                    get: { !isHidden },
                    set: { store.setCollectionPhraseHidden(collectionID: collection.id, phraseWord: candidate.phrase.word, hidden: !$0) }
                )) {
                    Text(isHidden ? "Hidden" : "Shown")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .toggleStyle(.switch)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var addNewPagePhraseButton: some View {
        Button {
            store.openNewPhraseEditor()
        } label: {
            Label("New", systemImage: "plus")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel("Add new phrase")
        .help("Add a new phrase")
    }

    @ViewBuilder
    private func pagePhraseLibraryActions(for phrase: PhraseItem, isAdded: Bool, isBase: Bool) -> some View {
        if !isAdded {
            Button {
                addPagePhrase(phrase)
            } label: {
                Image(systemName: "plus")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .radixIconButtonSurface(size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add phrase")
            .help("Add phrase")
        } else if !isBase {
            Button(role: .destructive) {
                phrasePendingDeletion = phrase
            } label: {
                Image(systemName: "trash")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .radixIconButtonSurface(size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete phrase")
            .help("Delete phrase")
        } else {
            Button {
                store.removeDataEditPhrase(word: phrase.word)
                pagePhraseActionMessage = "\(phrase.word) reverted."
                RadixHaptics.success()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .radixIconButtonSurface(size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Revert phrase")
            .help("Revert phrase")
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { phrasePendingDeletion != nil },
            set: { if !$0 { phrasePendingDeletion = nil } }
        )
    }

    private var deleteConfirmationMessage: String {
        guard let phrasePendingDeletion else {
            return "This removes the phrase from your added phrases."
        }
        return "Delete \(phrasePendingDeletion.word)? This removes it from your added phrases. Hidden page-phrase settings are separate."
    }

    private func addPagePhrase(_ phrase: PhraseItem) {
        do {
            try store.addCustomPhrase(
                word: phrase.word,
                pinyin: phrase.pinyin,
                meanings: phrase.meanings,
                notes: phrase.notes
            )
            pagePhraseActionMessage = "\(phrase.word) added."
            RadixHaptics.success()
        } catch {
            pagePhraseActionMessage = "Add failed: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    private func deletePendingPhrase() {
        guard let phrase = phrasePendingDeletion else { return }
        phrasePendingDeletion = nil
        do {
            _ = try store.removeAddedPhrases(words: [phrase.word])
            pagePhraseActionMessage = "\(phrase.word) deleted."
            RadixHaptics.success()
        } catch {
            pagePhraseActionMessage = "Delete failed: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }
}
