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
        PhraseResultRules.pinyinSortPredicate(lhs, rhs)
    }

    func sortPhrasesByPinyin(_ phrases: [PhraseItem]) -> [PhraseItem] {
        PhraseResultRules.sortedByPinyin(phrases)
    }

    // MARK: - Text normalization

    func normalizedCompactQuery(_ text: String) -> String {
        PinyinSearchNormalizer.normalizedCompactQuery(text)
    }

    func isLikelyPinyinQuery(_ text: String) -> Bool {
        RadixTextClassifier.isLikelyPinyinQuery(text)
    }

    func containsChineseCharacters(_ text: String) -> Bool {
        RadixTextClassifier.containsChineseCharacters(text)
    }

    // MARK: - Phrase lookup helpers

    func mergePhraseResults(primary: [PhraseItem], secondary: [PhraseItem]) -> [PhraseItem] {
        PhraseResultRules.mergedUniqueByWord(primary: primary, secondary: secondary)
    }

    func phraseLookupTarget(for target: String) -> String {
        let simplified = simplifiedText(target).trimmingCharacters(in: .whitespacesAndNewlines)
        return simplified.isEmpty ? target : simplified
    }

    var phraseLengthFilterOptions: [Int?] {
        PhraseLengthRule.filterOptions
    }

    func phraseLengthFilterLabel(for length: Int?) -> String {
        PhraseLengthRule.label(for: length)
    }

    var activePhraseLengthFilterLabel: String {
        phraseLengthFilterLabel(for: phraseLength)
    }

    func phraseLookupLengths(for length: Int?) -> [Int] {
        PhraseLengthRule.lookupLengths(selectedLength: length, maxPhraseLength: phraseRepo.maxPhraseLength())
    }

    func phraseCacheKey(character: String, length: Int?) -> String {
        "\(character)|\(phraseLengthCacheKey(for: length))"
    }

    private func phraseLengthCacheKey(for length: Int?) -> String {
        PhraseLengthRule.cacheKey(for: length)
    }

    func rankedPhraseResults(_ phrases: [PhraseItem]) -> [PhraseItem] {
        sortPhrasesByPinyin(phrases)
    }

    func phraseCandidates(containing lookupTarget: String, originalTarget: String, length: Int, includeHidden: Bool = false) -> [PhraseItem] {
        phraseCandidates(containing: lookupTarget, originalTarget: originalTarget, lengths: [length], includeHidden: includeHidden)
    }

    func phraseCandidates(containing lookupTarget: String, originalTarget: String, length: Int?, includeHidden: Bool = false) -> [PhraseItem] {
        phraseCandidates(containing: lookupTarget, originalTarget: originalTarget, lengths: phraseLookupLengths(for: length), includeHidden: includeHidden)
    }

    func phraseCandidates(containing lookupTarget: String, originalTarget: String, lengths: [Int], includeHidden: Bool = false) -> [PhraseItem] {
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
                for phrase in phraseRepo.phrases(containing: target, length: length, includeHidden: includeHidden) where seenPhrases.insert(phrase.id).inserted {
                    result.append(phrase)
                }
            }
        }
        return result
    }

    // MARK: - Image phrase context / highlight

    func imagePhraseContext(for character: String, offset: Int) -> ImagePhraseContext? {
        guard route == .search, homeTab == .filter, let collection = selectedBrowseCollection else { return nil }
        guard collection.characters.indices.contains(offset),
              collection.characters[offset] == character
        else { return nil }
        return ImagePhraseContext(collectionID: collection.id, target: character, offset: offset)
    }

}
