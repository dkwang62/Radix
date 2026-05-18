import SwiftUI

extension FilterGridTab {
    @ViewBuilder
    func imageGridContent(collection: CharacterCollection, proxy: ScrollViewProxy) -> some View {
        let allItems = browseImageGridItems(for: collection)

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
                            fontSize: fontSize,
                            isFavorite: store.isFavorite(character),
                            background: BrowseImageTileStyle.background(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                            stroke: BrowseImageTileStyle.stroke(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                            strokeWidth: highlightRole == nil ? 2 : 2.5,
                            matchPhraseTileTextSize: true
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
                        isActive: isActive
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
                        ContentUnavailableView(
                            "No page phrases",
                            systemImage: "text.quote",
                            description: Text("Radix did not find any 2, 3, or 4 character dictionary phrases on this page.")
                        )
                    } else {
                        List {
                            Section {
                                ForEach(candidates) { candidate in
                                    phraseChoiceRow(candidate, collection: collection)
                                }
                            } footer: {
                                Text("Hide phrases that do not fit this page context. Hidden here only changes this saved page.")
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    ContentUnavailableView("Page not found", systemImage: "photo.on.rectangle")
                }
            }
            .navigationTitle("Page Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func phraseChoiceRow(_ candidate: BrowsePagePhraseCandidate, collection: CharacterCollection) -> some View {
        let word = store.normalizedPhraseWord(candidate.phrase.word)
        let isHidden = collection.hiddenPhraseWords?.contains(word) == true

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
}
