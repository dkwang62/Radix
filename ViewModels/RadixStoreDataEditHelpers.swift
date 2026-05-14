import Foundation

/*
 RADIX STORE — DATA EDIT HELPERS
 =================================
 Form apply/build/clear, dictionary refresh, entry merge logic,
 phrase storage utilities, and profile export/import.
 Extracted from RadixStore Private Utilities.
*/

extension RadixStore {

    // MARK: - Refresh / persist

    func persistDataEditAndRefresh() throws {
        phraseCache.removeAll()
        refreshAddedDictionaryCharacters()
        if hasPerformedSearch { performSearch(customQuery: lastSearchQuery, recordHistory: false) }
        recomputeGridItems()
        if let current = previewCharacter, componentRepo.hasCharacter(current) {
            select(character: current, announce: false)
        }
        Task {
            let allChars = componentRepo.search(query: "", scriptFilter: .any, limit: Int.max)
            let radicals = ["none"] + componentRepo.availableRadicals()
            let structures = ["none"] + componentRepo.availableStructures()
            await MainActor.run {
                allCharactersCache = allChars
                availableRadicalFilters = radicals
                availableStructureFilters = structures
                if !radicals.contains(rootRadicalFilter) { rootRadicalFilter = "none" }
                if !structures.contains(rootStructureFilter) { rootStructureFilter = "none" }
            }
            await MainActor.run { calculateDictionaryVariances() }
        }
    }

    func refreshAddedDictionaryCharacters() {
        rootsDerivativesCache.removeAll()
        let allChanged = componentRepo.changedCharacters
        let added = Set(componentRepo.addedCharacters)
        let sorted = allChanged.sorted {
            let lhsDate = overlayAddedDates[$0]
            let rhsDate = overlayAddedDates[$1]
            switch (lhsDate, rhsDate) {
            case let (l?, r?): return l > r
            case (.some, nil): return true
            case (nil, .some): return false
            default: return $0 < $1
            }
        }
        addedDictionaryCharacters = sorted.filter { added.contains($0) }
        changedDictionaryCharacters = sorted
        editedDictionaryCharacters = sorted.filter { !added.contains($0) }
        baseDictionaryCoreEditedCharacters = sorted.filter { baseDictionaryCoreFieldsChanged($0) }
        dictionaryCharactersWithNotes = sorted.filter { dictionaryNotesChangedAndNonEmpty($0) }
        editedDictionaryCharactersSet = Set(editedDictionaryCharacters)
    }

    func refreshAllCharactersCache() {
        allCharactersCache = componentRepo.search(query: "", scriptFilter: .any, limit: Int.max)
    }

    func refreshAddedPhrases() {
        addedPhrases = phraseRepo.fetchAddedPhrases()
    }

    func refreshPhraseBackedViews(for character: String?) {
        phraseCache.removeAll()
        refreshAddedPhrases()
        syncDataEditPhraseCaches()
        dataEditPhrases = addedPhrases
        if let character, !character.isEmpty {
            let entry = componentRepo.entry(for: character) ?? emptyEntryTemplate()
            applyDataEditEntryToForm(entry, addedPhrases, favorites.contains(character))
        }
        refreshPhrases()
        if hasPerformedSearch || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            performSearch(recordHistory: false)
        }
    }

    func syncDataEditPhraseCaches() {
        for (key, value) in dataEditCache {
            dataEditCache[key] = (entry: value.entry, phrases: addedPhrases, isFav: value.isFav)
        }
    }

    // MARK: - Form apply / build / clear

    func applyDataEditEntryToForm(_ entry: RawComponentEntry, _ phrases: [PhraseItem], _ isFav: Bool) {
        isApplyingDatasetEntry = true
        defer { isApplyingDatasetEntry = false }
        let meta = entry.meta
        dataEditVariant = meta.variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        dataEditAdditionalVariants = (meta.additionalVariants ?? []).joined(separator: ", ")
        dataEditDefinition = meta.definition ?? ""
        dataEditPinyin = meta.pinyin?.list.joined(separator: "\n") ?? ""
        dataEditDecomposition = (meta.decomposition ?? meta.idc ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        dataEditRadical = meta.radical ?? ""
        switch meta.strokes {
        case .int(let value):    dataEditStrokes = String(value)
        case .string(let value): dataEditStrokes = value
        case .none:              dataEditStrokes = ""
        }
        dataEditCompounds = (meta.compounds?.list ?? []).joined(separator: "\n")
        dataEditEtymologyType = meta.etymology?.type
        dataEditEtymHint = meta.etymology?.hint?.text ?? ""
        dataEditEtymDetails = meta.etymology?.details?.text ?? ""
        dataEditNotes = meta.notes?.list.joined(separator: "\n") ?? ""
        dataEditRelatedCharacters = entry.relatedCharacters.joined(separator: "\n")
        dataEditIsFavourite = isFav
    }

    func buildDataEditEntryFromForm() -> RawComponentEntry {
        let pinyinParts = splitCSVOrLines(dataEditPinyin)
        let pinyinValue: StringOrMany = pinyinParts.count <= 1
            ? .single(pinyinParts.first ?? "")
            : .many(pinyinParts)
        let strokesText = dataEditStrokes.trimmingCharacters(in: .whitespacesAndNewlines)
        let strokesValue: IntOrString = Int(strokesText).map(IntOrString.int) ?? .string(strokesText)
        let etymology = RawEtymology(
            type: dataEditEtymologyType?.trimmingCharacters(in: .whitespacesAndNewlines),
            hint: .single(dataEditEtymHint.trimmingCharacters(in: .whitespacesAndNewlines)),
            details: .single(dataEditEtymDetails.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        let decompValue = dataEditDecomposition.trimmingCharacters(in: .whitespacesAndNewlines)
        return RawComponentEntry(
            relatedCharacters: splitCSVOrLines(dataEditRelatedCharacters),
            meta: RawMeta(
                variant: { let t = dataEditVariant.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t }(),
                additionalVariants: { let p = splitCSVOrLines(dataEditAdditionalVariants); return p.isEmpty ? nil : p }(),
                pinyin: pinyinValue,
                definition: dataEditDefinition.trimmingCharacters(in: .whitespacesAndNewlines),
                decomposition: decompValue,
                idc: decompValue,
                radical: dataEditRadical.trimmingCharacters(in: .whitespacesAndNewlines),
                strokes: strokesValue,
                compounds: .many(splitCSVOrLines(dataEditCompounds)),
                etymology: etymology,
                notes: .many(splitLinesKeepingSentences(dataEditNotes))
            )
        )
    }

    func clearDataEditForm() {
        isApplyingDatasetEntry = true
        defer { isApplyingDatasetEntry = false }
        dataEditCharacter = ""
        dataEditDefinition = ""
        dataEditPinyin = ""
        dataEditDecomposition = ""
        dataEditRadical = ""
        dataEditStrokes = ""
        dataEditCompounds = ""
        dataEditVariant = ""
        dataEditAdditionalVariants = ""
        dataEditEtymologyType = nil
        dataEditEtymHint = ""
        dataEditEtymDetails = ""
        dataEditNotes = ""
        dataEditRelatedCharacters = ""
        dataEditIsFavourite = false
    }

    // MARK: - Form parsing helpers

    func splitCSVOrLines(_ value: String) -> [String] {
        value.split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func splitLinesKeepingSentences(_ value: String) -> [String] {
        value.split(whereSeparator: { $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Dictionary change classification

    func baseDictionaryCoreFieldsChanged(_ character: String) -> Bool {
        BackupSummaryBuilder.dictionaryCoreFieldsChanged(
            base: componentRepo.baseEntry(for: character),
            edited: componentRepo.overlayUpserts[character]
        )
    }

    func dictionaryNotesChangedAndNonEmpty(_ character: String) -> Bool {
        BackupSummaryBuilder.dictionaryNotesChangedAndNonEmpty(
            base: componentRepo.baseEntry(for: character),
            edited: componentRepo.overlayUpserts[character]
        )
    }

    // MARK: - Entry merge logic

    func mergeNonConflictingEntry(local: RawComponentEntry, backup: RawComponentEntry, base: RawComponentEntry, restoredAt: Date) -> RawComponentEntry {
        let localMeta = local.meta
        let backupMeta = backup.meta
        let baseMeta = base.meta
        let mergedMeta = RawMeta(
            variant: mergeField(localMeta.variant, backupMeta.variant, baseMeta.variant),
            additionalVariants: mergeField(localMeta.additionalVariants, backupMeta.additionalVariants, baseMeta.additionalVariants),
            pinyin: mergeField(localMeta.pinyin, backupMeta.pinyin, baseMeta.pinyin),
            definition: mergeField(localMeta.definition, backupMeta.definition, baseMeta.definition),
            decomposition: mergeField(localMeta.decomposition, backupMeta.decomposition, baseMeta.decomposition),
            idc: mergeField(localMeta.idc, backupMeta.idc, baseMeta.idc),
            radical: mergeField(localMeta.radical, backupMeta.radical, baseMeta.radical),
            strokes: mergeField(localMeta.strokes, backupMeta.strokes, baseMeta.strokes),
            compounds: mergeField(localMeta.compounds, backupMeta.compounds, baseMeta.compounds),
            etymology: mergeField(localMeta.etymology, backupMeta.etymology, baseMeta.etymology),
            notes: mergeNotes(local: localMeta.notes, backup: backupMeta.notes, restoredAt: restoredAt)
        )
        return RawComponentEntry(
            relatedCharacters: mergeRequiredField(local.relatedCharacters, backup.relatedCharacters, base.relatedCharacters),
            meta: mergedMeta
        )
    }

    func entryByReplacingNotes(in entry: RawComponentEntry, with notes: StringOrMany) -> RawComponentEntry {
        let meta = entry.meta
        return RawComponentEntry(
            relatedCharacters: entry.relatedCharacters,
            meta: RawMeta(
                variant: meta.variant, additionalVariants: meta.additionalVariants, pinyin: meta.pinyin,
                definition: meta.definition, decomposition: meta.decomposition, idc: meta.idc,
                radical: meta.radical, strokes: meta.strokes, compounds: meta.compounds,
                etymology: meta.etymology, notes: notes
            )
        )
    }

    func mergeField<T: Equatable>(_ local: T?, _ backup: T?, _ base: T?) -> T? {
        guard let backup else { return local }
        return (local == nil || local == base) ? backup : local
    }

    func mergeRequiredField<T: Equatable>(_ local: T, _ backup: T, _ base: T) -> T {
        local == base ? backup : local
    }

    func mergeNotes(local: StringOrMany?, backup: StringOrMany?, restoredAt: Date) -> StringOrMany? {
        let localLines = local?.list ?? []
        let backupLines = backup?.list ?? []
        guard !backupLines.isEmpty else { return local }
        guard !localLines.isEmpty else { return backup }
        if localLines == backupLines || local?.text == backup?.text { return local }
        let formatter = ISO8601DateFormatter()
        let marker = "Restored backup notes \(formatter.string(from: restoredAt))"
        var merged = localLines
        if !merged.contains(marker) { merged.append(marker) }
        for line in backupLines where !merged.contains(line) { merged.append(line) }
        return .many(merged)
    }

    // MARK: - Phrase storage utilities

    func uniquePhrases(_ phrases: [PhraseItem]) -> [PhraseItem] {
        var seen = Set<String>()
        var result: [PhraseItem] = []
        for phrase in phrases {
            let key = phraseStorageWord(phrase.word)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(PhraseItem(
                word: key,
                pinyin: phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
                meanings: phrase.meanings.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                addedAt: phrase.addedAt
            ))
        }
        return result
    }

    func phraseStorageWord(_ word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let simplified = simplifiedText(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        return simplified.isEmpty ? trimmed : simplified
    }

    func removeLegacyPhraseIfNeeded(originalWord: String, storedWord: String) throws {
        guard originalWord != storedWord, phraseRepo.isInAdd(word: originalWord) else { return }
        try phraseRepo.deletePhrase(word: originalWord)
    }

    // MARK: - Profile export / import

    func exportProfileData() throws -> Data {
        try JSONEncoder().encode(currentUserProfile())
    }

    func currentUserProfile() -> UserProfile {
        let sortedFavorites = Array(favorites).sorted()
        let sortedFavoritePhrases = Array(favoritePhrases).sorted()
        return UserProfile(
            schemaVersion: 4,
            favouritesList: sortedFavorites,
            favouriteEntries: sortedFavorites.map { FavouriteProfileEntry(character: $0, addedAt: favoriteAddedDates[$0]) },
            favouritePhrasesList: sortedFavoritePhrases,
            favouritePhraseEntries: sortedFavoritePhrases.map { FavouritePhraseProfileEntry(word: $0, addedAt: favoritePhraseDates[$0]) },
            rememberedList: rootBreadcrumb,
            searchHistory: searchHistory,
            previewCharacter: previewCharacter,
            lastSearchQuery: lastSearchQuery.isEmpty ? nil : lastSearchQuery,
            currentSearchQuery: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : query,
            searchMode: searchMode.rawValue,
            scriptFilter: scriptFilter.rawValue,
            homeTab: homeTab.rawValue,
            route: route.rawValue,
            phraseLength: phraseLength,
            promptConfig: promptConfig,
            promptSelectedTaskIDs: promptSelectedTaskIDs,
            defaultAISettings: DefaultAISettings(preset: defaultAIPreset, customURLString: customAIURLString)
        )
    }

    func currentAPIKeyBackup() -> APIKeyBackup {
        APIKeyBackup(
            openAI: openAIAPIKey,
            gemini: geminiAPIKey,
            claude: claudeAPIKey,
            deepSeek: deepSeekAPIKey,
            custom: customAIAPIKey
        )
    }

    func applyImportedAPIKeys(_ apiKeys: APIKeyBackup?) {
        guard let apiKeys else { return }
        openAIAPIKey = apiKeys.openAI
        geminiAPIKey = apiKeys.gemini
        claudeAPIKey = apiKeys.claude
        deepSeekAPIKey = apiKeys.deepSeek
        customAIAPIKey = apiKeys.custom
    }

    func importProfileData(_ data: Data) throws {
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        applyImportedProfile(profile, mode: .complete)
    }
}
