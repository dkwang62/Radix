import Foundation

/*
 RADIX STORE - DATA MAINTENANCE
 ==============================
 Database optimization, sentence phrase-link maintenance, and storage health.
 Kept separate from Character Studio edit/import operations so render-time and
 Settings-triggered maintenance work has one clear home.
*/

private struct SentencePhraseLinkCandidate: Sendable {
    let word: String
    let key: String
}

private func storagePhraseWord(_ word: String) -> String {
    let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
    let simplified = ScriptTextConverter.simplified(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
    return simplified.isEmpty ? trimmed : simplified
}

private func sentencePhraseLinkCandidates(from phraseWords: [String]) -> [SentencePhraseLinkCandidate] {
    var seen = Set<String>()
    return phraseWords.compactMap { phrase in
        let word = storagePhraseWord(phrase)
        let key = SentenceExampleRecord.normalizedChineseKey(word)
        guard word.count >= 2, !key.isEmpty, seen.insert(word).inserted else { return nil }
        return SentencePhraseLinkCandidate(word: word, key: key)
    }
}

private func orderedSentencePhraseLinksForCandidates(in sentence: String, candidates: [SentencePhraseLinkCandidate]) -> [String] {
    let sentenceKey = SentenceExampleRecord.normalizedChineseKey(storagePhraseWord(sentence))
    var seen = Set<String>()
    return candidates.compactMap { candidate -> SentencePhraseLinkCandidate? in
        guard sentenceKey.contains(candidate.key), seen.insert(candidate.word).inserted else { return nil }
        return candidate
    }
    .sorted {
        let lhsPosition = sentenceKey.range(of: $0.key)?.lowerBound
        let rhsPosition = sentenceKey.range(of: $1.key)?.lowerBound
        if lhsPosition != rhsPosition {
            if lhsPosition == nil { return false }
            if rhsPosition == nil { return true }
            return lhsPosition! < rhsPosition!
        }
        if $0.key.count != $1.key.count { return $0.key.count > $1.key.count }
        return $0.key < $1.key
    }
    .map(\.word)
}

private func refreshingAICleanedPagePhraseLinks(
    in records: [AICleanedPageRecord],
    candidates: [SentencePhraseLinkCandidate]
) -> (records: [AICleanedPageRecord], changedPageCount: Int) {
    var updatedRecords = records
    var changedPageCount = 0
    for pageIndex in updatedRecords.indices {
        let original = updatedRecords[pageIndex]
        updatedRecords[pageIndex].sentences = original.sentences.map { sentence in
            var updated = sentence
            updated.phraseHints = orderedSentencePhraseLinksForCandidates(in: sentence.chinese, candidates: candidates)
            return updated
        }
        if updatedRecords[pageIndex] != original {
            changedPageCount += 1
        }
    }
    return (updatedRecords, changedPageCount)
}

private func stableOptimizationHash(_ values: [String]) -> String {
    let hash = values.reduce(UInt64(14_695_981_039_346_656_037)) { seed, value in
        value.utf8.reduce(seed) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
    return String(hash, radix: 16)
}

extension RadixStore {
    private var databaseOptimizationAlgorithmVersion: Int { 4 }
    private var databaseOptimizationFingerprintKey: String { "radix.databaseOptimization.lastFingerprint.v1" }
    private var databaseOptimizationDirtyKey: String { "radix.databaseOptimization.dirty.v1" }
    private var databaseOptimizationLastRunKey: String { "radix.databaseOptimization.lastRun.v1" }

    @discardableResult
    func refreshSentencePhraseLinks() -> SentencePhraseLinkRefreshResult {
        _ = try? createSentenceDatabaseSafetySnapshot(reason: "Before refreshing sentence phrase links")
        let phraseWords = activeSentencePhraseLinkWords()
        let extractedPageCount = refreshAICleanedPagePhraseLinks(availablePhraseWords: phraseWords)
        if extractedPageCount > 0 {
            try? RadixStudyPreferences.recordSentenceExamples(
                RadixStudyPreferences.aiCleanedPages.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))
            )
        }
        let sentenceCount = RadixStudyPreferences.refreshSentencePhraseLinks(availablePhraseWords: phraseWords)
        favoriteSentenceRevision += 1
        return SentencePhraseLinkRefreshResult(sentenceCount: sentenceCount, extractedPageCount: extractedPageCount)
    }

    @discardableResult
    func refreshSentencePhraseLinksForSettings(createSafetySnapshot: Bool = true) async -> SentencePhraseLinkRefreshResult {
        if createSafetySnapshot {
            _ = try? await createSentenceDatabaseSafetySnapshotForSettings(reason: "Before refreshing sentence phrase links")
        }
        let phraseWords = await activeSentencePhraseLinkWordsForSettings()
        let extractedPageCount = await refreshAICleanedPagePhraseLinksForOptimization(availablePhraseWords: phraseWords)
        if extractedPageCount > 0 {
            try? RadixStudyPreferences.recordSentenceExamples(
                RadixStudyPreferences.aiCleanedPages.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))
            )
        }
        let sentenceCount = await Task.detached(priority: .userInitiated) {
            RadixStudyPreferences.refreshSentencePhraseLinks(availablePhraseWords: phraseWords)
        }.value
        favoriteSentenceRevision += 1
        return SentencePhraseLinkRefreshResult(sentenceCount: sentenceCount, extractedPageCount: extractedPageCount)
    }

    func startDatabaseOptimization(reason: String = "Optimizing database", includeStorageCleanup: Bool = false) {
        if databaseOptimizationInProgress {
            databaseOptimizationMessage = "Optimizing… Radix is still usable."
            return
        }

        databaseOptimizationTask?.cancel()
        databaseOptimizationInProgress = true
        databaseOptimizationMessage = includeStorageCleanup
            ? "Optimizing… Radix is cleaning and preparing study data in the background."
            : "Checking database… Radix is still usable."

        databaseOptimizationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if !includeStorageCleanup {
                    let startingFingerprint = await self.databaseOptimizationFingerprintForSettings()
                    if !self.isDatabaseOptimizationNeeded(for: startingFingerprint) {
                        self.databaseOptimizationMessage = "Radix data is already optimized."
                        self.databaseOptimizationInProgress = false
                        self.databaseOptimizationTask = nil
                        try? await Task.sleep(for: .seconds(5))
                        guard !Task.isCancelled, !self.databaseOptimizationInProgress else { return }
                        self.databaseOptimizationMessage = nil
                        return
                    }
                }

                self.databaseOptimizationMessage = includeStorageCleanup
                    ? "Optimizing… Radix is cleaning and preparing study data in the background."
                    : "Optimizing… Radix is still usable."

                let status: String
                if includeStorageCleanup {
                    let result = try await self.normalizeChineseStorageToSimplifiedForSettings()
                    status = "\(reason) complete: prepared \(result.sentenceCount) sentence\(result.sentenceCount == 1 ? "" : "s") and \(result.phraseCount) added phrase\(result.phraseCount == 1 ? "" : "s")."
                } else {
                    let result = await self.refreshSentencePhraseLinksForSettings(createSafetySnapshot: false)
                    self.recordDatabaseOptimizationFingerprint(await self.databaseOptimizationFingerprintForSettings())
                    status = "\(reason) complete: optimized \(result.sentenceCount) sentence\(result.sentenceCount == 1 ? "" : "s")."
                }
                guard !Task.isCancelled else { return }
                self.databaseOptimizationMessage = "Optimization complete."
                self.dataEditAutoSaveStatus = status
            } catch {
                guard !Task.isCancelled else { return }
                let message = "Could not optimize Radix data: \(error.localizedDescription)"
                self.databaseOptimizationMessage = message
                self.dataEditAutoSaveStatus = message
            }
            self.databaseOptimizationInProgress = false
            self.databaseOptimizationTask = nil
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, !self.databaseOptimizationInProgress else { return }
            self.databaseOptimizationMessage = nil
        }
    }

    func markDatabaseOptimizationNeeded() {
        preferences.set(true, forKey: databaseOptimizationDirtyKey)
    }

    func storageHealth() -> RadixStorageHealth {
        let sentenceStats = RadixStudyPreferences.sentenceStorageStats()
        let extractedPages = RadixStudyPreferences.aiCleanedPages
        let largestExtractedPageSentenceCount = extractedPages.map { $0.sentences.count }.max() ?? 0
        let lastOptimizedTimestamp = preferences.double(forKey: databaseOptimizationLastRunKey)
        return RadixStorageHealth(
            sentenceCount: sentenceStats.count,
            sentenceDatabaseByteCount: sentenceStats.byteCount,
            addedPhraseCount: phraseRepo.addedPhraseCount(),
            addedPhraseDatabaseByteCount: phraseRepo.addedPhraseDatabaseByteCount(),
            extractedPageCount: extractedPages.count,
            largestExtractedPageSentenceCount: largestExtractedPageSentenceCount,
            optimizationMayBeNeeded: preferences.bool(forKey: databaseOptimizationDirtyKey),
            lastOptimizedAt: lastOptimizedTimestamp > 0 ? Date(timeIntervalSince1970: lastOptimizedTimestamp) : nil
        )
    }

    private func isDatabaseOptimizationNeeded(for fingerprint: String) -> Bool {
        if preferences.string(forKey: databaseOptimizationFingerprintKey) == fingerprint {
            preferences.set(false, forKey: databaseOptimizationDirtyKey)
            return false
        }
        return true
    }

    func recordDatabaseOptimizationFingerprint(_ fingerprint: String) {
        preferences.set(fingerprint, forKey: databaseOptimizationFingerprintKey)
        preferences.set(false, forKey: databaseOptimizationDirtyKey)
        preferences.set(Date().timeIntervalSince1970, forKey: databaseOptimizationLastRunKey)
    }

    func databaseOptimizationFingerprint() -> String {
        let sentenceStats = RadixStudyPreferences.sentenceOptimizationStats()
        let pages = RadixStudyPreferences.aiCleanedPages.sorted {
            if $0.sourcePageID != $1.sourcePageID {
                return $0.sourcePageID.uuidString < $1.sourcePageID.uuidString
            }
            return $0.createdAt < $1.createdAt
        }
        var pageValues: [String] = []
        var pageSentenceCount = 0
        for page in pages {
            pageValues.append(page.sourcePageID.uuidString)
            pageValues.append(String(Int(page.createdAt.timeIntervalSince1970)))
            for sentence in page.sentences {
                pageSentenceCount += 1
                pageValues.append(SentenceExampleRecord.normalizedChineseKey(storagePhraseWord(sentence.chinese)))
            }
        }

        return [
            "v\(databaseOptimizationAlgorithmVersion)",
            "sentences:\(sentenceStats.count):\(sentenceStats.latestCreatedAt):\(sentenceStats.latestUpdatedAt):\(sentenceStats.normalizedKeyHash)",
            "pages:\(pages.count):\(pageSentenceCount):\(stableOptimizationHash(pageValues))"
        ].joined(separator: "|")
    }

    func databaseOptimizationFingerprintForSettings() async -> String {
        databaseOptimizationFingerprint()
    }

    func refreshSentencePhraseLinksAfterAddingPhrase(_ word: String) {
        let storedWord = phraseStorageWord(word)
        guard !storedWord.isEmpty, phraseRepo.fetchPhrase(for: storedWord) != nil else { return }
        _ = RadixStudyPreferences.addSentencePhraseLink(storedWord)
        _ = addAICleanedPagePhraseLink(storedWord)
        favoriteSentenceRevision += 1
    }

    func refreshSentencePhraseLinksAfterRemovingPhrases(_ words: [String]) {
        let storedWords = words.map(phraseStorageWord(_:)).filter { !$0.isEmpty }
        guard !storedWords.isEmpty else { return }
        _ = RadixStudyPreferences.removeSentencePhraseLinks(storedWords)
        _ = removeAICleanedPagePhraseLinks(storedWords)
        favoriteSentenceRevision += 1
    }

    private func activeSentencePhraseLinkWords() -> [String] {
        phraseRepo.activeSentencePhraseLinkWords()
    }

    private func activeSentencePhraseLinkWordsForSettings() async -> [String] {
        let words = await Task.detached(priority: .utility) {
            let repository = PhraseRepository()
            do {
                try repository.openFromBundle()
                defer { repository.close() }
                return repository.activeSentencePhraseLinkWords()
            } catch {
                return []
            }
        }.value
        return words.isEmpty ? activeSentencePhraseLinkWords() : words
    }

    private func refreshAICleanedPagePhraseLinks(availablePhraseWords words: [String]) -> Int {
        var records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        let candidates = sentencePhraseLinkCandidates(from: words)
        let result = refreshingAICleanedPagePhraseLinks(in: records, candidates: candidates)
        records = result.records
        let changedPageCount = result.changedPageCount
        if changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = records
        }
        return changedPageCount
    }

    private func refreshAICleanedPagePhraseLinksForOptimization(availablePhraseWords words: [String]) async -> Int {
        let records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        let candidates = sentencePhraseLinkCandidates(from: words)
        let result = await Task.detached(priority: .utility) {
            refreshingAICleanedPagePhraseLinks(in: records, candidates: candidates)
        }.value
        if result.changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = result.records
        }
        return result.changedPageCount
    }

    private func addAICleanedPagePhraseLink(_ word: String) -> Int {
        let storedWord = phraseStorageWord(word)
        guard storedWord.count >= 2 else { return 0 }
        var records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        var changedPageCount = 0
        for pageIndex in records.indices {
            let original = records[pageIndex]
            records[pageIndex].sentences = original.sentences.map { sentence in
                let sentenceKey = SentenceExampleRecord.normalizedChineseKey(phraseStorageWord(sentence.chinese))
                let phraseKey = SentenceExampleRecord.normalizedChineseKey(storedWord)
                guard sentenceKey.contains(phraseKey), !sentence.phraseHints.map(phraseStorageWord(_:)).contains(storedWord) else {
                    return sentence
                }
                var updated = sentence
                updated.phraseHints = orderedSentencePhraseLinks(in: sentence.chinese, phraseWords: sentence.phraseHints + [storedWord])
                return updated
            }
            if records[pageIndex] != original {
                changedPageCount += 1
            }
        }
        if changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = records
        }
        return changedPageCount
    }

    private func removeAICleanedPagePhraseLinks(_ words: [String]) -> Int {
        let removedWords = Set(words.map(phraseStorageWord(_:)).filter { !$0.isEmpty })
        guard !removedWords.isEmpty else { return 0 }
        var records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        var changedPageCount = 0
        for pageIndex in records.indices {
            let original = records[pageIndex]
            records[pageIndex].sentences = original.sentences.map { sentence in
                var updated = sentence
                updated.phraseHints = sentence.phraseHints.filter {
                    !removedWords.contains(phraseStorageWord($0))
                }
                return updated
            }
            if records[pageIndex] != original {
                changedPageCount += 1
            }
        }
        if changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = records
        }
        return changedPageCount
    }

    private func orderedSentencePhraseLinks(in sentence: String, phraseWords: [String]) -> [String] {
        orderedSentencePhraseLinksForCandidates(in: sentence, candidates: sentencePhraseLinkCandidates(from: phraseWords))
    }

    func normalizeFavoritePhraseStorage() {
        var normalizedPhrases = Set<String>()
        var normalizedDates: [String: Date] = [:]
        for phrase in favoritePhrases {
            let storedWord = phraseStorageWord(phrase)
            guard !storedWord.isEmpty else { continue }
            normalizedPhrases.insert(storedWord)
            let existingDate = normalizedDates[storedWord]
            let candidateDate = favoritePhraseDates[phrase]
            normalizedDates[storedWord] = [existingDate, candidateDate].compactMap { $0 }.min()
        }
        favoritePhrases = normalizedPhrases
        favoritePhraseDates = normalizedDates
        persistFavoritePhrases()
    }
}
