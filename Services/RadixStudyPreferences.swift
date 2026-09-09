import Foundation

enum SentenceExampleLookup: Equatable, Sendable {
    case character(String)
    case phrase(String)

    var searchText: String {
        switch self {
        case .character(let character):
            return character
        case .phrase(let phrase):
            return phrase
        }
    }
}

struct SentenceExampleLookupPage: Equatable, Sendable {
    var records: [SentenceExampleRecord]
    var nextOffset: Int?
}

enum RadixStudyPreferences {
    private static let usesTraditionalScriptKey = "studyGridUsesTraditionalScript"
    private static let gridScopeKey = "studyGridScope"
    private static let savedPagesDefaultMigrationKey = "studyGridScopeSavedPagesDefaultV1"
    private static let pageSortOrderKey = "studyPageSortOrder"
    private static let hasDismissedIntroKey = "hasDismissedStudyIntroV1"
    private static let preferences = RadixPreferences.standard
    private static let sentenceLibrary = SentenceLibraryStore(
        canonicalize: canonicalizedSentenceExamples,
        simplify: ScriptTextConverter.simplified,
        matchesSearchText: sentenceExample(_:matchesSearchText:)
    )
    private static let conversationPracticeStore = ConversationPracticeStore(preferences: preferences)
    private static let pageArtifactStore = PageStudyArtifactStore(preferences: preferences)

    static var usesTraditionalScript: Bool {
        get { preferences.bool(forKey: usesTraditionalScriptKey) }
        set { preferences.set(newValue, forKey: usesTraditionalScriptKey) }
    }

    static var gridScope: StudyGridScope {
        get {
            guard let rawValue = preferences.string(forKey: gridScopeKey) else {
                return .savedPages
            }
            return StudyGridScope(rawValue: rawValue) ?? .savedPages
        }
        set { preferences.set(newValue.rawValue, forKey: gridScopeKey) }
    }

    static var initialGridScope: StudyGridScope {
        migrateSavedPagesDefaultIfNeeded()
        return gridScope
    }

    static func migrateSavedPagesDefaultIfNeeded() {
        guard preferences.object(forKey: savedPagesDefaultMigrationKey) == nil else { return }
        gridScope = .savedPages
        preferences.set(true, forKey: savedPagesDefaultMigrationKey)
    }

    static var pageSortOrder: PageCollectionSortOrder {
        get {
            guard let rawValue = preferences.string(forKey: pageSortOrderKey) else {
                return .lastViewed
            }
            return PageCollectionSortOrder(rawValue: rawValue) ?? .lastViewed
        }
        set { preferences.set(newValue.rawValue, forKey: pageSortOrderKey) }
    }

    static var hasDismissedIntro: Bool {
        get { preferences.bool(forKey: hasDismissedIntroKey) }
        set { preferences.set(newValue, forKey: hasDismissedIntroKey) }
    }

    static var importedConversationPracticePacks: [ConversationPracticePack] {
        get { conversationPracticeStore.importedPacks }
        set { conversationPracticeStore.importedPacks = newValue }
    }

    static var conversationPracticeProgress: ConversationPracticeProgressSnapshot {
        get { conversationPracticeStore.progress }
        set { conversationPracticeStore.progress = newValue }
    }

    static var favoriteSentences: [FavoriteSentenceRecord] {
        get {
            guard let data = preferences.data(forKey: RadixPreferenceKey.favoriteSentences) else {
                return []
            }
            return canonicalizedFavoriteSentences(
                (try? JSONDecoder().decode([FavoriteSentenceRecord].self, from: data)) ?? []
            )
        }
        set {
            let data = try? JSONEncoder().encode(canonicalizedFavoriteSentences(newValue))
            preferences.set(data, forKey: RadixPreferenceKey.favoriteSentences)
        }
    }

    static var sentenceExamples: [SentenceExampleRecord] {
        sentenceLibrary.fetchAll(migratingLegacy: legacySentenceExamplesFromPreferences)
    }

    @discardableResult
    static func createSentenceDatabaseSnapshot(reason: String) throws -> RadixDatabaseSnapshotMetadata {
        let date = Date()
        let destinationURL = try RadixDatabaseSnapshotStore.destinationURL(kind: .sentenceExamples, date: date)
        try sentenceLibrary.backupDatabase(to: destinationURL)
        return RadixDatabaseSnapshotStore.record(kind: .sentenceExamples, reason: reason, at: destinationURL, date: date)
    }

    static func restoreSentenceDatabaseSnapshot(_ snapshot: RadixDatabaseSnapshotMetadata) throws {
        guard snapshot.kind == .sentenceExamples else {
            throw NSError(domain: "Radix", code: 3140, userInfo: [NSLocalizedDescriptionKey: "This snapshot is not a sentence database snapshot."])
        }
        try sentenceLibrary.restoreDatabase(from: URL(fileURLWithPath: snapshot.path))
    }

    static func exportSentenceDatabaseData() throws -> Data {
        prepareExtractedPageSentenceExamplesForBackup()
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("radix_sentence_database_export_\(UUID().uuidString)")
            .appendingPathExtension("db")
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try sentenceLibrary.backupDatabase(to: exportURL)
        return try Data(contentsOf: exportURL)
    }

    @discardableResult
    static func importSentenceDatabase(from sourceURL: URL, mode: RestoreMode) throws -> Int {
        try SentenceLibraryStore.validateSentenceDatabase(at: sourceURL)
        switch mode {
        case .additive:
            let sourceRepository = SentenceLibraryStore(
                databaseURL: sourceURL,
                canonicalize: canonicalizedSentenceExamples,
                simplify: ScriptTextConverter.simplified,
                matchesSearchText: sentenceExample(_:matchesSearchText:)
            )
            let importedRecords = sourceRepository.fetchAll(migratingLegacy: { [] })
            try sentenceLibrary.upsert(canonicalizedSentenceExamples(importedRecords))
            refreshConversationPracticePackSentenceReferences()
            return importedRecords.count
        case .complete:
            try sentenceLibrary.restoreDatabase(from: sourceURL)
            refreshConversationPracticePackSentenceReferences()
            return sentenceExampleCount()
        }
    }

    static func clearSentenceDatabase() throws {
        try sentenceLibrary.replaceAll([])
        preferences.removeObject(forKey: RadixPreferenceKey.sentenceExamples)
        favoriteSentences = []
    }

    static func clearUserLearningData() throws {
        try clearSentenceDatabase()
        conversationPracticeStore.clearUserData()
        pageArtifactStore.clearUserData()
    }

    static func reconcileSentenceSourcesAfterDeletingPages(
        _ pageIDs: Set<UUID>
    ) throws -> SentencePageSourceReconciliationResult {
        try sentenceLibrary.reconcileSources(
            removingPageIDs: pageIDs,
            migratingLegacy: legacySentenceExamplesFromPreferences
        )
    }

    static var currentSentenceExamples: [SentenceExampleRecord] {
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
        return sentenceExamples
    }

    static func querySentenceExamples(_ query: SentenceExampleQuery) -> SentenceExampleQueryResult {
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
        return sentenceLibrary.query(query, migratingLegacy: legacySentenceExamplesFromPreferences)
    }

    static func querySentenceExamplePage(
        _ query: SentenceExampleQuery,
        requestedPageIndex: Int,
        pageSize: Int
    ) -> SentenceExamplePageQueryResult {
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
        return sentenceLibrary.queryPage(
            query,
            requestedPageIndex: requestedPageIndex,
            pageSize: pageSize,
            migratingLegacy: legacySentenceExamplesFromPreferences
        )
    }

    static func sentenceExampleCount(scope: SentenceExampleQueryScope = .all, searchText: String = "") -> Int {
        querySentenceExamples(SentenceExampleQuery(scope: scope, searchText: searchText, offset: 0, limit: 0)).totalCount
    }

    static var hasSentenceExamples: Bool {
        sentenceExampleCount() > 0
    }

    static func sentenceExamples(matching query: SentenceExampleQuery) -> [SentenceExampleRecord] {
        var allQuery = query
        allQuery.offset = 0
        allQuery.limit = nil
        return querySentenceExamples(allQuery).records
    }

    static func sentenceExample(id: UUID) -> SentenceExampleRecord? {
        sentenceLibrary.fetch(id: id, migratingLegacy: legacySentenceExamplesFromPreferences)
    }

    static func sentenceExample(normalizedKey: String) -> SentenceExampleRecord? {
        sentenceLibrary.fetch(
            normalizedKey: normalizedKey,
            migratingLegacy: legacySentenceExamplesFromPreferences
        )
    }

    static func sentenceExamples(normalizedKeys: [String]) -> [String: SentenceExampleRecord] {
        sentenceLibrary.fetch(
            normalizedKeys: normalizedKeys,
            migratingLegacy: legacySentenceExamplesFromPreferences
        )
    }

    static func recordSentenceExamples(_ records: [SentenceExampleRecord]) throws {
        guard !records.isEmpty else { return }
        try sentenceLibrary.upsert(canonicalizedSentenceExamples(records))
    }

    static func sentenceOptimizationStats() -> SentenceExampleOptimizationStats {
        sentenceLibrary.optimizationStats(migratingLegacy: legacySentenceExamplesFromPreferences)
    }

    static func sentenceStorageStats() -> SentenceExampleStorageStats {
        SentenceExampleStorageStats(
            count: sentenceExampleCount(),
            byteCount: sentenceLibrary.databaseByteCount()
        )
    }

    @discardableResult
    static func refreshSentencePhraseLinks(availablePhraseWords words: [String]) throws -> Int {
        let records = currentSentenceExamples
        guard !records.isEmpty else { return 0 }
        let phraseWords = canonicalizedPhraseLinkWords(words)
        let updatedRecords = records.map {
            sentenceExample($0, refreshingPhraseLinksFrom: phraseWords)
        }
        let changedRecords = zip(records, updatedRecords).compactMap { original, updated in
            original == updated ? nil : updated
        }
        try sentenceLibrary.replace(changedRecords)
        return changedRecords.count
    }

    @discardableResult
    static func addSentencePhraseLink(_ phrase: String) throws -> Int {
        let phraseWords = canonicalizedPhraseLinkWords([phrase])
        guard let phraseWord = phraseWords.first else { return 0 }
        let matchingRecords = sentenceExamplesContainingChineseText(phraseWord)
        let updatedRecords = matchingRecords.compactMap { record -> SentenceExampleRecord? in
            let updated = sentenceExample(record, refreshingPhraseLinksFrom: phraseWords)
            return updated == record ? nil : updated
        }
        try sentenceLibrary.replace(updatedRecords)
        return updatedRecords.count
    }

    @discardableResult
    static func removeSentencePhraseLinks(_ phrases: [String]) throws -> Int {
        let phraseKeys = Set(canonicalizedPhraseLinkWords(phrases))
        guard !phraseKeys.isEmpty else { return 0 }
        var recordsByID: [UUID: SentenceExampleRecord] = [:]
        for phrase in phraseKeys {
            for record in sentenceExamples(matching: SentenceExampleQuery(searchText: phrase)) {
                recordsByID[record.id] = record
            }
        }
        let updatedRecords = recordsByID.values.compactMap { record -> SentenceExampleRecord? in
            var updated = record
            updated.targetPhrases = record.targetPhrases.filter {
                !phraseKeys.contains(SentenceExampleRecord.normalizedChineseKey(ScriptTextConverter.simplified($0)))
            }
            updated.detectedPhrases = record.detectedPhrases.filter {
                !phraseKeys.contains(SentenceExampleRecord.normalizedChineseKey(ScriptTextConverter.simplified($0)))
            }
            return updated == record ? nil : updated
        }
        try sentenceLibrary.replace(updatedRecords)
        return updatedRecords.count
    }

    @discardableResult
    static func convertStoredSentenceExamplesToSimplified() throws -> Int {
        let records = currentSentenceExamples
        guard !records.isEmpty else {
            favoriteSentences = canonicalizedFavoriteSentences(favoriteSentences)
            return 0
        }
        let converted = canonicalizedSentenceExamples(records)
        try sentenceLibrary.replaceAll(converted)
        favoriteSentences = canonicalizedFavoriteSentences(favoriteSentences)
        return converted.count
    }

    static func recordSentenceExamples(from pack: ConversationPracticePack, createdAt: Date = Date()) throws {
        let favoriteIDs = Set(favoriteSentences.map(\.sourceItemID))
        let records = pack.practiceItems.map { item in
            SentenceExampleRecord.fromPracticeItem(
                item,
                pack: pack,
                isFavorited: favoriteIDs.contains(item.id),
                createdAt: createdAt
            )
        }
        try recordSentenceExamples(records)
    }

    @discardableResult
    static func recordSentenceExamples(fromCaptureText text: String, createdAt: Date = Date()) throws -> [SentenceExampleRecord] {
        let records = canonicalizedSentenceExamples(
            RadixCaptureJSONParser.sentenceExamples(from: text, createdAt: createdAt)
        )
        try recordSentenceExamples(records)
        return records
    }

    static func canonicalizedConversationPracticePack(_ pack: ConversationPracticePack) throws -> ConversationPracticePack {
        try recordSentenceExamples(from: pack)
        return pack.withCanonicalSentenceReferences(from: sentenceExamples)
    }

    @discardableResult
    static func migrateImportedConversationPracticePacksIntoSentenceExamples() -> Bool {
        let packs = importedConversationPracticePacks
        guard !packs.isEmpty else { return false }
        var didMigrate = false
        let migrated = packs.map { pack -> ConversationPracticePack in
            guard pack.needsCanonicalSentenceReferences else { return pack }
            didMigrate = true
            return (try? canonicalizedConversationPracticePack(pack)) ?? pack
        }
        if didMigrate {
            importedConversationPracticePacks = migrated
        }
        return didMigrate
    }

    static func prepareSentenceExamplesForBackup() {
        migrateImportedConversationPracticePacksIntoSentenceExamples()
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
    }

    static func prepareExtractedPageSentenceExamplesForBackup() {
        prepareSentenceExamplesForBackup()
        let extractedPageSentences = aiCleanedPages.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))
        try? recordSentenceExamples(extractedPageSentences)
    }

    static func refreshConversationPracticePackSentenceReferences() {
        let packs = importedConversationPracticePacks
        guard !packs.isEmpty else { return }
        importedConversationPracticePacks = packs.map {
            $0.withCanonicalSentenceReferences(from: sentenceExamples)
        }
    }

    static func setSentenceExampleFavorite(_ item: ConversationPracticeItem, isFavorited: Bool) throws {
        let incoming = SentenceExampleRecord.fromPracticeItem(item, pack: nil, isFavorited: isFavorited)
        let key = incoming.normalizedChineseKey
        if var existing = sentenceLibrary.fetch(normalizedKey: key, migratingLegacy: legacySentenceExamplesFromPreferences) {
            existing.isFavorited = isFavorited
            existing.qualityScore = max(0, existing.qualityScore + (isFavorited ? 2 : -2))
            try recordSentenceExamples([existing])
        } else {
            try recordSentenceExamples([incoming])
        }
        setCompatibilityFavoriteRecord(FavoriteSentenceRecord(item: item), isFavorited: isFavorited)
    }

    static func setSentenceExampleFavorite(id: UUID, isFavorited: Bool) throws {
        var updatedRecord: SentenceExampleRecord?
        try updateSentenceExample(id: id) { record in
            record.isFavorited = isFavorited
            record.qualityScore = max(0, record.qualityScore + (isFavorited ? 2 : -2))
            updatedRecord = record
        }
        if let updatedRecord {
            setCompatibilityFavoriteRecord(FavoriteSentenceRecord(sentenceExample: updatedRecord), isFavorited: isFavorited)
        }
    }

    static func setSentenceExampleHidden(id: UUID, isHidden: Bool) throws {
        try updateSentenceExample(id: id) { record in
            record.isHidden = isHidden
        }
    }

    static func replaceSentenceExample(_ updated: SentenceExampleRecord) throws {
        guard let previous = sentenceLibrary.fetch(id: updated.id, migratingLegacy: legacySentenceExamplesFromPreferences) else {
            if let conflict = sentenceLibrary.fetch(normalizedKey: updated.normalizedChineseKey, migratingLegacy: legacySentenceExamplesFromPreferences),
               conflict.id != updated.id {
                throw sentenceIdentityConflictError()
            }
            try recordSentenceExamples([updated])
            if updated.isFavorited {
                setCompatibilityFavoriteRecord(FavoriteSentenceRecord(sentenceExample: updated), isFavorited: true)
            }
            return
        }

        if let conflict = sentenceLibrary.fetch(normalizedKey: updated.normalizedChineseKey, migratingLegacy: legacySentenceExamplesFromPreferences),
           conflict.id != updated.id {
            throw sentenceIdentityConflictError()
        }

        try sentenceLibrary.replace([updated])
        replaceAICleanedPageSentence(previous: previous, updated: updated)
        if previous.normalizedChineseKey != updated.normalizedChineseKey {
            removeCompatibilityFavoriteRecord(matchingChinese: previous.chinese)
        }

        if updated.isFavorited {
            setCompatibilityFavoriteRecord(FavoriteSentenceRecord(sentenceExample: updated), isFavorited: true)
        } else {
            removeCompatibilityFavoriteRecord(matchingChinese: updated.chinese)
        }
    }

    private static func replaceAICleanedPageSentence(
        previous: SentenceExampleRecord,
        updated: SentenceExampleRecord
    ) {
        let pageIDs = previous.sources.compactMap { source -> UUID? in
            guard source.sourceType == .aiCleanedPage else { return nil }
            return source.sourcePageID
        }
        guard !pageIDs.isEmpty else { return }

        var records = aiCleanedPages
        var didChange = false

        for index in records.indices where pageIDs.contains(records[index].sourcePageID) {
            var record = records[index]
            if record.replaceSentence(previous: previous, updated: updated) {
                records[index] = record
                didChange = true
            }
        }

        if didChange {
            aiCleanedPages = records
        }
    }

    static func deleteSentenceExample(id: UUID) throws {
        let deleted = sentenceLibrary.fetch(id: id, migratingLegacy: legacySentenceExamplesFromPreferences)
        try sentenceLibrary.delete(id: id)
        if let deleted {
            removeCompatibilityFavoriteRecord(matchingChinese: deleted.chinese)
        }
    }

    static func deleteSentenceExamples(ids: [UUID]) throws {
        let records = ids.compactMap {
            sentenceLibrary.fetch(id: $0, migratingLegacy: legacySentenceExamplesFromPreferences)
        }
        try sentenceLibrary.delete(ids: ids)
        for record in records {
            removeCompatibilityFavoriteRecord(matchingChinese: record.chinese)
        }
    }

    static func deleteSentenceExample(matchingChinese chinese: String) throws {
        let key = SentenceExampleRecord.normalizedChineseKey(chinese)
        guard !key.isEmpty else { return }
        let deleted = sentenceLibrary.fetch(normalizedKey: key, migratingLegacy: legacySentenceExamplesFromPreferences)
        try sentenceLibrary.delete(normalizedKey: key)
        if let deleted {
            removeCompatibilityFavoriteRecord(matchingChinese: deleted.chinese)
        } else {
            removeCompatibilityFavoriteRecord(matchingChinese: chinese)
        }
    }

    private static func updateSentenceExample(id: UUID, mutate: (inout SentenceExampleRecord) -> Void) throws {
        guard var record = sentenceLibrary.fetch(id: id, migratingLegacy: legacySentenceExamplesFromPreferences) else { return }
        mutate(&record)
        try recordSentenceExamples([record])
    }

    static func migrateLegacyFavoriteSentencesIntoSentenceExamples() {
        let records = favoriteSentences
        guard !records.isEmpty else { return }
        let missingRecords = records.compactMap { record -> SentenceExampleRecord? in
            let incoming = SentenceExampleRecord.fromFavoriteSentence(record)
            if let existing = sentenceLibrary.fetch(
                normalizedKey: incoming.normalizedChineseKey,
                migratingLegacy: legacySentenceExamplesFromPreferences
            ), existing.isFavorited {
                return nil
            }
            return incoming
        }
        try? recordSentenceExamples(missingRecords)
    }

    static func setCompatibilityFavoriteRecord(_ record: FavoriteSentenceRecord, isFavorited: Bool) {
        if isFavorited {
            favoriteSentences = favoriteSentences + [record]
        } else {
            removeCompatibilityFavoriteRecord(matchingChinese: record.simplified)
        }
    }

    static func removeCompatibilityFavoriteRecord(matchingChinese chinese: String) {
        let simplifiedChinese = ScriptTextConverter.simplified(chinese)
        let id = FavoriteSentenceRecord.identifier(forChinese: simplifiedChinese)
        favoriteSentences = favoriteSentences.filter { record in
            record.id != id &&
                SentenceExampleRecord.normalizedChineseKey(record.simplified) != SentenceExampleRecord.normalizedChineseKey(simplifiedChinese)
        }
    }

    static func favoriteSentenceExamples() -> [SentenceExampleRecord] {
        sentenceExamples(matching: SentenceExampleQuery(scope: .favorites))
    }

    static func sentenceExamples(containingCharacter character: String, limit: Int? = nil) -> [SentenceExampleRecord] {
        exactSentenceExamples(matching: .character(character), limit: limit)
    }

    static func sentenceExamples(containingPhrase phrase: String, limit: Int? = nil) -> [SentenceExampleRecord] {
        exactSentenceExamples(matching: .phrase(phrase), limit: limit)
    }

    static func sentenceExamplePage(
        matching lookup: SentenceExampleLookup,
        offset: Int,
        limit: Int
    ) -> SentenceExampleLookupPage {
        let resultLimit = max(1, limit)
        let queryPageSize = max(24, min(120, resultLimit * 4))
        var queryOffset = max(0, offset)
        var matches: [SentenceExampleRecord] = []

        while matches.count < resultLimit {
            let result = querySentenceExamples(
                SentenceExampleQuery(
                    searchText: lookup.searchText,
                    offset: queryOffset,
                    limit: queryPageSize
                )
            )
            guard !result.records.isEmpty else {
                return SentenceExampleLookupPage(records: matches, nextOffset: nil)
            }

            for (index, record) in result.records.enumerated() where sentenceExample(record, matches: lookup) {
                matches.append(record)
                if matches.count == resultLimit {
                    let nextOffset = queryOffset + index + 1
                    return SentenceExampleLookupPage(
                        records: matches,
                        nextOffset: nextOffset < result.totalCount ? nextOffset : nil
                    )
                }
            }

            queryOffset += result.records.count
            if queryOffset >= result.totalCount {
                return SentenceExampleLookupPage(records: matches, nextOffset: nil)
            }
        }

        return SentenceExampleLookupPage(records: matches, nextOffset: nil)
    }

    static func sentenceExamples(linkedToPageID pageID: UUID, limit: Int? = nil) -> [SentenceExampleRecord] {
        sentenceExamples(matching: SentenceExampleQuery(scope: .page(pageID, nil), offset: 0, limit: limit))
    }

    static func sentenceExamples(sourceType: SentenceExampleSourceType, limit: Int? = nil) -> [SentenceExampleRecord] {
        sentenceExamples(matching: SentenceExampleQuery(scope: .sourceType(sourceType), offset: 0, limit: limit))
    }

    static func applyImportedSentenceExamples(_ records: [SentenceExampleRecord]?, mode: RestoreMode) throws {
        switch mode {
        case .additive:
            try recordSentenceExamples(records ?? [])
        case .complete:
            try sentenceLibrary.replaceAll(canonicalizedSentenceExamples(records ?? []))
        }
        refreshConversationPracticePackSentenceReferences()
    }

    static func sentenceExample(_ example: SentenceExampleRecord, containsPhrase phrase: String) -> Bool {
        let simplifiedPhrase = ScriptTextConverter.simplified(phrase)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !simplifiedPhrase.isEmpty else { return false }
        return example.containsPhrase(simplifiedPhrase)
    }

    static func sentenceExample(_ example: SentenceExampleRecord, matchesSearchText query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }
        if sentenceExample(example, containsPhrase: trimmedQuery) {
            return true
        }

        let simplifiedQuery = ScriptTextConverter.simplified(trimmedQuery)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let haystack = [
            example.chinese,
            example.pinyin ?? "",
            example.english ?? "",
            example.targetPhrases.joined(separator: " "),
            example.detectedPhrases.joined(separator: " "),
            example.targetCharacters.joined(separator: " "),
            example.detectedCharacters.joined(separator: " "),
            example.sources.compactMap(\.sourceTitle).joined(separator: " "),
            example.tags.joined(separator: " ")
        ]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let foldedQuery = trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let foldedSimplifiedQuery = simplifiedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return haystack.contains(foldedQuery) || haystack.contains(foldedSimplifiedQuery)
    }

    private static func exactSentenceExamples(
        matching lookup: SentenceExampleLookup,
        limit: Int?
    ) -> [SentenceExampleRecord] {
        let pageSize = max(1, min(120, limit ?? 24))
        var nextOffset: Int? = 0
        var matches: [SentenceExampleRecord] = []

        while let offset = nextOffset {
            let page = sentenceExamplePage(matching: lookup, offset: offset, limit: pageSize)
            matches.append(contentsOf: page.records)
            if let limit, matches.count >= limit {
                return Array(matches.prefix(limit))
            }
            nextOffset = page.nextOffset
        }

        return matches
    }

    private static func sentenceExample(
        _ record: SentenceExampleRecord,
        matches lookup: SentenceExampleLookup
    ) -> Bool {
        switch lookup {
        case .character(let character):
            return record.containsCharacter(character)
        case .phrase(let phrase):
            return sentenceExample(record, containsPhrase: phrase)
        }
    }

    private static func legacySentenceExamplesFromPreferences() -> [SentenceExampleRecord] {
        guard let data = preferences.data(forKey: RadixPreferenceKey.sentenceExamples) else {
            return []
        }
        return (try? JSONDecoder().decode([SentenceExampleRecord].self, from: data)) ?? []
    }

    fileprivate static func canonicalizedSentenceExamples(_ records: [SentenceExampleRecord]) -> [SentenceExampleRecord] {
        SentenceExampleRecord.upserting(records.map(canonicalizedSentenceExample(_:)), into: [])
    }

    private static func canonicalizedPhraseLinkWords(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.compactMap { word in
            let simplified = ScriptTextConverter.simplified(word)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = SentenceExampleRecord.normalizedChineseKey(simplified)
            guard simplified.count >= 2, !key.isEmpty, seen.insert(key).inserted else { return nil }
            return key
        }
    }

    private static func sentenceExamplesContainingChineseText(_ text: String) -> [SentenceExampleRecord] {
        let key = SentenceExampleRecord.normalizedChineseKey(text)
        guard !key.isEmpty else { return [] }
        return sentenceExamples(matching: SentenceExampleQuery(searchText: text)).filter {
            $0.normalizedChineseKey.contains(key)
        }
    }

    private static func sentenceExample(
        _ record: SentenceExampleRecord,
        refreshingPhraseLinksFrom phraseWords: [String]
    ) -> SentenceExampleRecord {
        var updated = record
        let sentenceKey = record.normalizedChineseKey
        let matchedPhrases = orderedPhraseLinks(in: sentenceKey, phraseWords: phraseWords)
        updated.targetPhrases = matchedPhrases
        updated.detectedPhrases = matchedPhrases
        return updated
    }

    private static func orderedPhraseLinks(in normalizedSentence: String, phraseWords: [String]) -> [String] {
        phraseWords
            .filter { normalizedSentence.contains(SentenceExampleRecord.normalizedChineseKey($0)) }
            .sorted {
                let lhsKey = SentenceExampleRecord.normalizedChineseKey($0)
                let rhsKey = SentenceExampleRecord.normalizedChineseKey($1)
                let lhsPosition = normalizedSentence.range(of: lhsKey)?.lowerBound
                let rhsPosition = normalizedSentence.range(of: rhsKey)?.lowerBound
                if lhsPosition != rhsPosition {
                    if lhsPosition == nil { return false }
                    if rhsPosition == nil { return true }
                    return lhsPosition! < rhsPosition!
                }
                if lhsKey.count != rhsKey.count { return lhsKey.count > rhsKey.count }
                return lhsKey < rhsKey
            }
    }

    fileprivate static func canonicalizedSentenceExample(_ record: SentenceExampleRecord) -> SentenceExampleRecord {
        let simplifiedChinese = ScriptTextConverter.simplified(record.chinese)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedCharacters = SentenceExampleRecord.detectChineseCharacters(in: simplifiedChinese)
        return SentenceExampleRecord(
            id: record.id,
            chinese: simplifiedChinese,
            script: .simplified,
            pinyin: record.pinyin,
            english: record.english,
            sources: record.sources,
            targetCharacters: canonicalizedChineseList(record.targetCharacters),
            targetPhrases: canonicalizedChineseList(record.targetPhrases),
            detectedCharacters: detectedCharacters,
            detectedPhrases: canonicalizedChineseList(record.detectedPhrases),
            grammarPoints: record.grammarPoints,
            hskLevel: record.hskLevel,
            difficulty: record.difficulty,
            naturalness: record.naturalness,
            createdAt: record.createdAt,
            lastUsedAt: record.lastUsedAt,
            usageCount: record.usageCount,
            viewedCount: record.viewedCount,
            practicedCount: record.practicedCount,
            skippedCount: record.skippedCount,
            isFavorited: record.isFavorited,
            isHidden: record.isHidden,
            qualityScore: record.qualityScore,
            notes: record.notes,
            tags: record.tags
        )
    }

    private static func canonicalizedChineseList(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let simplified = ScriptTextConverter.simplified(value)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !simplified.isEmpty, seen.insert(simplified).inserted else { return nil }
            return simplified
        }
    }

    private static func canonicalizedFavoriteSentences(_ records: [FavoriteSentenceRecord]) -> [FavoriteSentenceRecord] {
        FavoriteSentenceRecord.deduplicated(records.map { record in
            let simplified = ScriptTextConverter.simplified(record.simplified)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return FavoriteSentenceRecord(
                id: FavoriteSentenceRecord.identifier(forChinese: simplified),
                simplified: simplified,
                pinyin: record.pinyin,
                english: record.english,
                sourceSetID: record.sourceSetID,
                sourceItemID: record.sourceItemID,
                phraseHints: canonicalizedChineseList(record.phraseHints),
                characterHints: canonicalizedChineseList(record.characterHints),
                favoritedAt: record.favoritedAt
            )
        })
    }

    static var pagePhraseExtractions: [PagePhraseExtractionRecord] {
        get { pageArtifactStore.phraseExtractions }
        set { pageArtifactStore.phraseExtractions = newValue }
    }

    static func recordPagePhraseExtraction(
        pageID: UUID,
        title: String,
        words: [String],
        extractedAt: Date = Date()
    ) {
        pageArtifactStore.recordPhraseExtraction(
            pageID: pageID,
            title: title,
            words: words,
            extractedAt: extractedAt
        )
    }

    static var aiCleanedPages: [AICleanedPageRecord] {
        get { pageArtifactStore.cleanedPages }
        set { pageArtifactStore.cleanedPages = newValue }
    }

    static func aiCleanedPage(for pageID: UUID) -> AICleanedPageRecord? {
        pageArtifactStore.cleanedPage(for: pageID)
    }

    static func recordAICleanedPage(_ record: AICleanedPageRecord) throws {
        let replacementSentences = SentenceExampleRecord.fromAICleanedPage(record)
        try reconcileAICleanedPageSentenceExamples(
            for: record.sourcePageID,
            replacementSentences: replacementSentences
        )
        pageArtifactStore.replaceCleanedPage(record)
    }

    private static func reconcileAICleanedPageSentenceExamples(
        for pageID: UUID,
        replacementSentences: [SentenceExampleRecord]
    ) throws {
        let replacementKeys = Set(replacementSentences.map(\.normalizedChineseKey).filter { !$0.isEmpty })
        let previousSentences = sentenceExamples(matching: SentenceExampleQuery(
            scope: .page(pageID, .aiCleanedPage)
        ))

        for previous in previousSentences where !replacementKeys.contains(previous.normalizedChineseKey) {
            var retained = previous
            retained.removeSources(sourceType: .aiCleanedPage, pageID: pageID)
            if retained.sources.isEmpty && !retained.isFavorited {
                try deleteSentenceExample(id: retained.id)
            } else {
                try sentenceLibrary.replace([retained])
            }
        }

        try recordSentenceExamples(replacementSentences)
    }

    static func applyImportedAICleanedPages(_ records: [AICleanedPageRecord]?, mode: RestoreMode) throws {
        switch mode {
        case .additive:
            guard let records, !records.isEmpty else { return }
            for record in records {
                try recordAICleanedPage(record)
            }
        case .complete:
            let records = records ?? []
            try sentenceLibrary.replaceAICleanedPageSources(
                with: canonicalizedSentenceExamples(records.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))),
                migratingLegacy: legacySentenceExamplesFromPreferences
            )
            aiCleanedPages = records
        }
    }

    private static func sentenceIdentityConflictError() -> Error {
        NSError(
            domain: "Radix",
            code: 3154,
            userInfo: [NSLocalizedDescriptionKey: "Another saved sentence already uses that Chinese text. Keep the sentences distinct or delete the duplicate first."]
        )
    }
}
