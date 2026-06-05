import Foundation

/*
 RADIX STORE — IMAGE PHRASE HIGHLIGHTS
 =======================================
 All logic for phrase highlighting within Browse collection image grids:
 tap handling, anchor/restore, memory highlights, and scroll targeting.
 All @Published state remains in RadixStore.swift.
*/

extension RadixStore {

    // MARK: - Image character tap

    func previewImageCharacter(_ character: String, offset: Int, announce: Bool = true) {
        clearBrowseMemoryHighlight()
        clearAnchoredImagePhraseHighlight()
        imagePhraseContext = nil
        imagePhraseHighlightOffsets = []
        imageBrowsePhrasePreview = nil
        sidebarPhrasePreview = nil
        imagePhraseHighlightRevision += 1
        preview(character: character, announce: announce, preservePhraseContext: false)
    }

    func previewPhraseCardCharacter(_ character: String, in phrase: PhraseItem, announce: Bool = false) {
        guard route == .search, homeTab == .filter, let collection = selectedBrowseCollection else {
            preview(character: character, announce: announce)
            return
        }

        let existingContext = imagePhraseContext
        let existingOffsets = imagePhraseHighlightOffsets
        let phraseOffsets = phraseHighlightOffsets(in: collection, word: phrase.word)

        dismissSidebarPhrasePreview()
        browsePreview(character: character, announce: announce, preservePhraseContext: true)

        let offsets = phraseOffsets.isEmpty ? existingOffsets : phraseOffsets
        guard !offsets.isEmpty else { return }

        let contextOffset: Int?
        if let existingContext,
           existingContext.collectionID == collection.id,
           collection.characters.indices.contains(existingContext.offset) {
            contextOffset = existingContext.offset
        } else {
            contextOffset = offsets.sorted().first { collection.characters.indices.contains($0) }
        }

        if let contextOffset {
            let contextCharacter = collection.characters[contextOffset]
            imagePhraseContext = imagePhraseContext(for: contextCharacter, offset: contextOffset) ?? existingContext
        }
        imagePhraseHighlightOffsets = offsets
        anchorImagePhraseHighlight(phraseWord: phrase.word, context: imagePhraseContext, offsets: offsets)
        imagePhraseHighlightRevision += 1
    }

    func imagePhraseHighlightRole(collectionID: UUID, offset: Int) -> ImagePhraseHighlightRole? {
        guard let context = imagePhraseContext, context.collectionID == collectionID else { return nil }
        if offset == context.offset { return .target }
        if imagePhraseHighlightOffsets.contains(offset) { return .phraseMember }
        return nil
    }

    // MARK: - Anchor / restore

    func anchorImagePhraseHighlight(context: ImagePhraseContext?, offsets: Set<Int>) {
        guard let context, offsets.count > 1 else { return }
        anchoredImagePhraseContext = context
        anchoredImagePhraseHighlightOffsets = offsets
        anchoredImagePhraseCollectionID = context.collectionID
    }

    func anchorImagePhraseHighlight(phraseWord: String, context: ImagePhraseContext?, offsets: Set<Int>) {
        anchorImagePhraseHighlight(context: context, offsets: offsets)
        if offsets.count > 1 { anchoredImagePhraseWord = phraseStorageWord(phraseWord) }
    }

    func clearAnchoredImagePhraseHighlight() {
        anchoredImagePhraseContext = nil
        anchoredImagePhraseHighlightOffsets = []
        anchoredImagePhraseWord = nil
        anchoredImagePhraseCollectionID = nil
    }

    func restoreAnchoredImagePhraseHighlightIfNeeded() {
        guard let collection = selectedBrowseCollection,
              let collectionID = anchoredImagePhraseCollectionID,
              collection.id == collectionID
        else { return }

        if let word = anchoredImagePhraseWord {
            let offsets = phraseHighlightOffsets(in: collection, word: word)
            if !offsets.isEmpty {
                let context = phraseHighlightContext(in: collection, offsets: offsets)
                imagePhraseContext = context
                imagePhraseHighlightOffsets = offsets
                anchoredImagePhraseContext = context
                anchoredImagePhraseHighlightOffsets = offsets
                imagePhraseHighlightRevision += 1
                return
            }
        }

        guard let context = anchoredImagePhraseContext,
              !anchoredImagePhraseHighlightOffsets.isEmpty
        else { return }
        imagePhraseContext = context
        imagePhraseHighlightOffsets = anchoredImagePhraseHighlightOffsets
        imagePhraseHighlightRevision += 1
    }

    // MARK: - Browse memory highlights

    @discardableResult
    func highlightMemoryMatchesInCurrentBrowseSource(_ item: String) -> Bool {
        let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard route == .search, homeTab == .filter, let collection = selectedBrowseCollection, !key.isEmpty else {
            clearBrowseMemoryHighlight()
            return false
        }

        let characters = collection.characters
        let lookupCharacters = characters.map { phraseLookupTarget(for: $0) }
        let lookupKey = phraseLookupTarget(for: key)
        imagePhraseContext = nil
        imagePhraseHighlightOffsets = []
        clearAnchoredImagePhraseHighlight()
        imageBrowsePhrasePreview = nil
        imagePhraseHighlightRevision += 1

        let result = BrowseMemoryHighlighter.matches(in: lookupCharacters, item: lookupKey)
        let offsets = result.offsets

        guard !offsets.isEmpty else { clearBrowseMemoryHighlight(); return false }

        browseMemoryHighlightCollectionID = collection.id
        browseMemoryHighlightOffsets = offsets
        browseMemoryHighlightedItem = key
        if let firstOffset = result.firstOffset {
            pendingBrowseScrollTarget = BrowseScrollTarget(
                collectionID: collection.id,
                character: characters.indices.contains(firstOffset) ? characters[firstOffset] : nil,
                offset: firstOffset
            )
        }
        return true
    }

    func clearBrowseMemoryHighlight() {
        browseMemoryHighlightCollectionID = nil
        browseMemoryHighlightOffsets = []
        browseMemoryHighlightedItem = nil
    }

    func isBrowseMemoryHighlighted(collectionID: UUID, offset: Int) -> Bool {
        browseMemoryHighlightCollectionID == collectionID && browseMemoryHighlightOffsets.contains(offset)
    }

    // MARK: - Scroll targeting

    func prepareBrowseReturnScrollTarget() {
        let phraseCharacter = activeSidebarPhrasePreview?.word.first.map(String.init)
        let targetCharacter = previewCharacter ?? phraseCharacter

        if let collection = selectedBrowseCollection {
            if let context = imagePhraseContext, context.collectionID == collection.id {
                pendingBrowseScrollTarget = BrowseScrollTarget(
                    collectionID: collection.id,
                    character: targetCharacter ?? context.target,
                    offset: context.offset
                )
                return
            }
            if let targetCharacter, let offset = collection.characters.firstIndex(of: targetCharacter) {
                pendingBrowseScrollTarget = BrowseScrollTarget(collectionID: collection.id, character: targetCharacter, offset: offset)
                return
            }
            if let offset = imagePhraseHighlightOffsets.sorted().first, collection.characters.indices.contains(offset) {
                pendingBrowseScrollTarget = BrowseScrollTarget(collectionID: collection.id, character: collection.characters[offset], offset: offset)
                return
            }
        }

        guard let targetCharacter else { return }
        pendingBrowseScrollTarget = BrowseScrollTarget(collectionID: nil, character: targetCharacter, offset: nil)
    }

    func consumePendingBrowseScrollTarget() -> BrowseScrollTarget? {
        let target = pendingBrowseScrollTarget
        pendingBrowseScrollTarget = nil
        return target
    }

    // MARK: - Computed highlight state

    var activeImagePhraseHighlightOffsets: Set<Int> {
        if !anchoredImagePhraseHighlightOffsets.isEmpty { return anchoredImagePhraseHighlightOffsets }
        if imagePhraseHighlightOffsets.count > 1 { return imagePhraseHighlightOffsets }
        return []
    }

    var shouldPreserveBrowseImagePhraseHighlight: Bool {
        guard route == .search, homeTab == .filter,
              selectedBrowseCollection != nil,
              !activeImagePhraseHighlightOffsets.isEmpty
        else { return false }
        return true
    }

    // MARK: - Phrase highlight helpers (used by anchor/restore and previewPhraseCardCharacter)

    func phraseHighlightOffsets(in collection: CharacterCollection, word: String) -> Set<Int> {
        let lookupCharacters = collection.characters.map { phraseLookupTarget(for: $0) }
        let lookupWord = phraseLookupTarget(for: phraseStorageWord(word))
        return BrowseMemoryHighlighter.matches(in: lookupCharacters, item: lookupWord).offsets
    }

    func phraseHighlightContext(in collection: CharacterCollection, offsets: Set<Int>) -> ImagePhraseContext? {
        if let context = anchoredImagePhraseContext,
           context.collectionID == collection.id,
           offsets.contains(context.offset),
           collection.characters.indices.contains(context.offset) {
            return context
        }
        guard let offset = offsets.sorted().first,
              collection.characters.indices.contains(offset)
        else { return nil }
        return imagePhraseContext(for: collection.characters[offset], offset: offset)
    }

    func handleMemoryHighlightedImageTap(character: String, offset: Int) -> Bool {
        guard let collection = selectedBrowseCollection,
              browseMemoryHighlightCollectionID == collection.id,
              browseMemoryHighlightOffsets.contains(offset),
              let highlightedItem = browseMemoryHighlightedItem,
              !highlightedItem.isEmpty
        else { return false }

        if highlightedItem.count == 1 {
            previewImageCharacter(character, offset: offset)
            return true
        }

        guard let phrase = mergedPhrase(for: highlightedItem) else { return false }

        let highlightedOffsets = browseMemoryHighlightOffsets
        clearBrowseMemoryHighlight()
        imagePhraseContext = imagePhraseContext(for: character, offset: offset)
        imagePhraseHighlightOffsets = highlightedOffsets
        anchorImagePhraseHighlight(phraseWord: phrase.word, context: imagePhraseContext, offsets: highlightedOffsets)
        imageBrowsePhrasePreview = phrase
        sidebarPhrasePreview = nil
        previewCharacter = character
        imagePhraseHighlightRevision += 1
        pushPhraseBreadcrumb(phrase)
        showBrowseHelp = false
        showComponentHelp = false
        if speechEnabled { speechService.speak(phrase.word) }
        return true
    }

    func browsePagePhraseTile(in collection: CharacterCollection, at offset: Int) -> BrowseImagePhraseTileData? {
        browsePagePhraseTiles(in: collection)[offset]
    }

    func browsePagePhraseTiles(in collection: CharacterCollection) -> [Int: BrowseImagePhraseTileData] {
        guard route == .search, homeTab == .filter,
              selectedBrowseCollectionID == collection.id,
              collection.characters.count > 1
        else { return [:] }
        if let cached = browsePagePhraseTileCache[collection.id] {
            return cached
        }

        let lookupCharacters = collection.characters.map { phraseLookupTarget(for: $0) }
        let maxPhraseLength = browsePageMaximumPhraseLength
        let phraseByLookupWord = browsePagePhraseLookup(in: collection, maxPhraseLength: maxPhraseLength)
        let hiddenWords = collection.hiddenPhraseWords ?? []

        let matches = browsePagePhraseTileMatches(
            lookupCharacters: lookupCharacters,
            phraseByLookupWord: phraseByLookupWord,
            hiddenWords: hiddenWords,
            maxPhraseLength: maxPhraseLength
        )

        let tiles = BrowsePagePhraseRules.tiles(from: matches)

        browsePagePhraseTileCache[collection.id] = tiles
        return tiles
    }

    func browsePagePhraseCandidates(in collection: CharacterCollection) -> [BrowsePagePhraseCandidate] {
        if let cached = browsePagePhraseCandidateCache[collection.id] {
            return cached
        }
        let lookupCharacters = collection.characters.map { phraseLookupTarget(for: $0) }
        let maxPhraseLength = browsePageMaximumPhraseLength
        let phraseByLookupWord = browsePagePhraseLookup(in: collection, maxPhraseLength: maxPhraseLength)
        let candidates = BrowsePagePhraseRules.candidates(
            lookupCharacters: lookupCharacters,
            phraseByLookupWord: phraseByLookupWord,
            maxPhraseLength: maxPhraseLength,
            phraseWordKey: phraseStorageWord
        )
        browsePagePhraseCandidateCache[collection.id] = candidates
        return candidates
    }

    private func browsePagePhraseLookup(in collection: CharacterCollection, maxPhraseLength: Int) -> [String: PhraseItem] {
        let lookupCharacters = collection.characters.map { phraseLookupTarget(for: $0) }
        let candidateWords = BrowsePagePhraseRules.candidateWords(
            lookupCharacters: lookupCharacters,
            maxPhraseLength: maxPhraseLength
        )
        let phrases = phraseRepo.fetchPhrases(matching: candidateWords, includeHidden: true)
        var phraseByLookupWord: [String: PhraseItem] = [:]
        for phrase in phrases {
            let key = phraseLookupTarget(for: phraseStorageWord(phrase.word))
            phraseByLookupWord[key] = phrase
        }
        return phraseByLookupWord
    }

    private var browsePageMaximumPhraseLength: Int {
        max(2, phraseRepo.maxPhraseLength())
    }

    private func browsePagePhraseTileMatches(
        lookupCharacters: [String],
        phraseByLookupWord: [String: PhraseItem],
        hiddenWords: Set<String>,
        maxPhraseLength: Int
    ) -> [BrowseImagePhraseTileData] {
        BrowsePagePhraseRules.tileMatches(
            lookupCharacters: lookupCharacters,
            phraseByLookupWord: phraseByLookupWord,
            hiddenWords: hiddenWords,
            maxPhraseLength: maxPhraseLength,
            phraseWordKey: phraseStorageWord
        )
    }

    func presentPhraseFromBrowseImageTile(_ phrase: PhraseItem, in collection: CharacterCollection, offsets: Set<Int>) {
        let context = phraseHighlightContext(in: collection, offsets: offsets)
        imagePhraseContext = context
        imagePhraseHighlightOffsets = offsets
        anchorImagePhraseHighlight(phraseWord: phrase.word, context: context, offsets: offsets)
        imageBrowsePhrasePreview = phrase
        sidebarPhrasePreview = nil
        previewCharacter = phrase.word.first.map(String.init)
        imagePhraseHighlightRevision += 1
        pushPhraseBreadcrumb(phrase)
        showBrowseHelp = false
        showComponentHelp = false
        if speechEnabled { speechService.speak(phrase.word) }
    }

}
