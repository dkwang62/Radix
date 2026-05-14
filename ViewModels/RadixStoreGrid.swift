import Foundation

/*
 RADIX STORE — GRID & PHRASE HELPERS
 =====================================
 Grid recompute, filter predicates, sort comparators, phrase candidate
 lookup, image phrase highlight plumbing, and text normalization utilities.
 Extracted from RadixStore Private Utilities.
*/

extension RadixStore {

    // MARK: - Grid recompute

    func scheduleGridRecompute() {
        pendingGridRecomputeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recomputeGridItems() }
        pendingGridRecomputeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(40), execute: work)
    }

    func recomputeGridItems() {
        Task {
            let result = buildGridItemsWithCounts()
            await MainActor.run {
                allGridItems = result.items
                allReadingOrderCharacters = result.readingOrder
                gridFilteredAllCount = result.allCount
                gridFilteredComponentCount = result.componentCount
            }
        }
    }

    // MARK: - Filter predicates

    func isNoFilter(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "none" || normalized == "any"
    }

    func rootFilterPredicate(_ item: ComponentItem) -> Bool {
        let lower = min(rootMinStroke, rootMaxStroke)
        let upper = max(rootMinStroke, rootMaxStroke)
        let strokeValue = item.strokes ?? 999
        let strokeMatch = strokeValue >= lower && strokeValue <= upper
        let radicalMatch = isNoFilter(rootRadicalFilter) || item.radical == rootRadicalFilter
        let structure = componentRepo.structureKey(for: item)
        let structureMatch = isNoFilter(rootStructureFilter) || structure == rootStructureFilter
        return strokeMatch && radicalMatch && structureMatch
    }

    // MARK: - Sort comparators

    func usageSortPredicate(_ lhs: ComponentItem, _ rhs: ComponentItem) -> Bool {
        let lhsGroup = lhs.usageCount >= 5 ? 0 : 1
        let rhsGroup = rhs.usageCount >= 5 ? 0 : 1
        if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }
        if lhsGroup == 0 {
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
        }
        let lRank = lhs.rank ?? 999999
        let rRank = rhs.rank ?? 999999
        if lRank != rRank { return lRank < rRank }
        if lhs.freqPerMillion != rhs.freqPerMillion { return lhs.freqPerMillion > rhs.freqPerMillion }
        return lhs.character < rhs.character
    }

    func frequencySortPredicate(_ lhs: ComponentItem, _ rhs: ComponentItem) -> Bool {
        let lRank = lhs.rank ?? 999999
        let rRank = rhs.rank ?? 999999
        if lRank != rRank { return lRank < rRank }
        if lhs.freqPerMillion != rhs.freqPerMillion { return lhs.freqPerMillion > rhs.freqPerMillion }
        if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
        return lhs.character < rhs.character
    }

    func phrasePinyinSortPredicate(_ lhs: PhraseItem, _ rhs: PhraseItem) -> Bool {
        let lhsPinyin = normalizedCompactQuery(lhs.pinyin)
        let rhsPinyin = normalizedCompactQuery(rhs.pinyin)
        if lhsPinyin != rhsPinyin { return lhsPinyin < rhsPinyin }
        if lhs.pinyin != rhs.pinyin { return lhs.pinyin < rhs.pinyin }
        return lhs.word < rhs.word
    }

    func sortPhrasesByPinyin(_ phrases: [PhraseItem]) -> [PhraseItem] {
        phrases.sorted(by: phrasePinyinSortPredicate)
    }

    // MARK: - Text normalization

    func normalizedCompactQuery(_ text: String) -> String {
        let mutable = NSMutableString(string: text.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return (mutable as String).filter { $0.isLetter || $0.isNumber }
    }

    func isLikelyPinyinQuery(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        return trimmed.unicodeScalars.allSatisfy {
            CharacterSet.letters.union(.decimalDigits).union(.whitespaces).contains($0)
        }
    }

    func containsChineseCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value)
        }
    }

    // MARK: - Phrase lookup helpers

    func mergePhraseResults(primary: [PhraseItem], secondary: [PhraseItem]) -> [PhraseItem] {
        var seen = Set<String>()
        var out: [PhraseItem] = []
        for item in (primary + secondary) {
            if seen.insert(item.word).inserted { out.append(item) }
        }
        return sortPhrasesByPinyin(out)
    }

    func phraseLookupTarget(for target: String) -> String {
        let simplified = simplifiedText(target).trimmingCharacters(in: .whitespacesAndNewlines)
        return simplified.isEmpty ? target : simplified
    }

    var phraseLengthFilterOptions: [Int?] {
        [nil, 2, 3, 4, 5, 6, 7]
    }

    func phraseLengthFilterLabel(for length: Int?) -> String {
        guard let length else { return "All" }
        return length >= 7 ? "7+" : "\(length)"
    }

    var activePhraseLengthFilterLabel: String {
        phraseLengthFilterLabel(for: phraseLength)
    }

    func phraseLookupLengths(for length: Int?) -> [Int] {
        guard let length else {
            return Array(2...max(2, phraseRepo.maxPhraseLength()))
        }
        if length >= 7 {
            return Array(7...max(7, phraseRepo.maxPhraseLength()))
        }
        return [length]
    }

    func phraseCacheKey(character: String, length: Int?, context: ImagePhraseContext?) -> String {
        ImagePhraseMatcher.cacheKey(character: character, lengthKey: phraseLengthCacheKey(for: length), context: context)
    }

    private func phraseLengthCacheKey(for length: Int?) -> String {
        guard let length else { return "all" }
        return length >= 7 ? "7plus" : String(length)
    }

    func rankedPhraseResults(_ phrases: [PhraseItem], target: String, context: ImagePhraseContext?) -> [PhraseItem] {
        sortPhrasesByPinyin(phrases)
    }

    func phraseCandidates(containing lookupTarget: String, originalTarget: String, length: Int) -> [PhraseItem] {
        phraseCandidates(containing: lookupTarget, originalTarget: originalTarget, lengths: [length])
    }

    func phraseCandidates(containing lookupTarget: String, originalTarget: String, length: Int?) -> [PhraseItem] {
        phraseCandidates(containing: lookupTarget, originalTarget: originalTarget, lengths: phraseLookupLengths(for: length))
    }

    func phraseCandidates(containing lookupTarget: String, originalTarget: String, lengths: [Int]) -> [PhraseItem] {
        let candidates = [
            lookupTarget,
            componentRepo.counterpart(for: originalTarget),
            componentRepo.counterpart(for: lookupTarget)
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

        var seenTargets = Set<String>()
        var seenPhrases = Set<String>()
        var result: [PhraseItem] = []
        for target in candidates where !target.isEmpty && seenTargets.insert(target).inserted {
            for length in lengths {
                for phrase in phraseRepo.phrases(containing: target, length: length) where seenPhrases.insert(phrase.id).inserted {
                    result.append(phrase)
                }
            }
        }
        return result
    }

    // MARK: - Image phrase context / highlight

    func imagePhraseContext(for character: String, offset: Int) -> ImagePhraseContext? {
        guard route == .search, homeTab == .filter, let collection = selectedBrowseCollection else { return nil }
        return ImagePhraseMatcher.context(for: character, offset: offset, collection: collection)
    }

    func phraseContext(for target: String) -> ImagePhraseContext? {
        guard route == .search, homeTab == .filter,
              let context = imagePhraseContext,
              context.target == target,
              selectedBrowseCollectionID == context.collectionID
        else { return nil }
        return context
    }

    func refreshImagePhraseHighlights(for character: String, context: ImagePhraseContext?) {
        guard let context else { updateImagePhraseHighlights(context: nil, phrases: []); return }
        let lookupTarget = phraseLookupTarget(for: character)
        Task {
            let highlightPhrases = phraseCandidates(
                containing: lookupTarget, originalTarget: character, lengths: imagePhraseHighlightLengths)
            await MainActor.run {
                guard self.imagePhraseContext == context else { return }
                self.updateImagePhraseHighlights(context: context, phrases: highlightPhrases)
            }
        }
    }

    func imagePhraseMatches(for context: ImagePhraseContext) -> [ImagePhraseMatch] {
        guard let collection = selectedBrowseCollection, collection.id == context.collectionID else { return [] }
        let lookupTarget = phraseLookupTarget(for: context.target)
        let candidates = phraseCandidates(
            containing: lookupTarget, originalTarget: context.target, lengths: imagePhraseHighlightLengths)
        return ImagePhraseMatcher.matches(
            context: context, collection: collection, candidates: candidates,
            phraseStorageWord: phraseStorageWord(_:),
            lookupTarget: phraseLookupTarget(for:),
            pinyinSort: phrasePinyinSortPredicate
        )
    }

    func preferredImagePhraseMatch(from matches: [ImagePhraseMatch], targetOffset: Int) -> ImagePhraseMatch {
        ImagePhraseMatcher.preferredMatch(from: matches, targetOffset: targetOffset)
    }

    func updateImagePhraseHighlights(context: ImagePhraseContext?, phrases: [PhraseItem]) {
        guard let context else { updateImagePhraseHighlights(context: nil, matches: []); return }
        updateImagePhraseHighlights(context: context, matches: imagePhraseMatches(for: context))
    }

    func updateImagePhraseHighlights(context: ImagePhraseContext?, matches: [ImagePhraseMatch]) {
        guard let context,
              let collection = selectedBrowseCollection,
              collection.id == context.collectionID,
              collection.characters.indices.contains(context.offset)
        else {
            imagePhraseHighlightOffsets = []
            clearAnchoredImagePhraseHighlight()
            imageBrowsePhrasePreview = nil
            sidebarPhrasePreview = nil
            imagePhraseHighlightRevision += 1
            return
        }
        var offsets: Set<Int> = [context.offset]
        for match in matches { offsets.formUnion(match.start..<match.end) }
        imagePhraseHighlightOffsets = offsets
        anchorImagePhraseHighlight(context: context, offsets: offsets)
        imagePhraseHighlightRevision += 1
        imagePhraseHighlightStateByCollectionID[context.collectionID] = ImagePhraseHighlightState(
            context: context, offsets: offsets)
    }

    func restoreImagePhraseHighlight(for collectionID: UUID) {
        guard let state = imagePhraseHighlightStateByCollectionID[collectionID],
              collection(id: collectionID) != nil else { return }
        imagePhraseContext = state.context
        imagePhraseHighlightOffsets = state.offsets
        imagePhraseHighlightRevision += 1
    }
}
