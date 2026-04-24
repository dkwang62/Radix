import Foundation

/*
 COMPONENT REPOSITORY
 ===================
 Manages the character dictionary backend (JSON). 
 
 KEY FEATURES:
 1. Dual-Key Structure: Supports both 'decomposition' and 'IDC' keys for compatibility.
 2. High-Speed Indexing: Maintains in-memory maps for character lookups and radical filtering.
 3. Script Detection: Intelligently identifies Simplified vs Traditional characters for UI filtering.
*/

enum ScriptFilter: String, CaseIterable, Identifiable {
    case any = "Any"
    case simplified = "Simplified"
    case traditional = "Traditional"

    var id: String { rawValue }
}

final class ComponentRepository {
    private let idcChars: Set<Character> = ["⿰", "⿱", "⿲", "⿳", "⿴", "⿵", "⿶", "⿷", "⿸", "⿹", "⿺", "⿻"]
    private(set) var byCharacter: [String: ComponentItem] = [:]
    private(set) var allCharacters: [String] = []
    private(set) var subtlexLoadedCount: Int = 0
    private(set) var activeDatasetURL: URL?
    private(set) var rawMap: [String: RawComponentEntry] = [:]
    private(set) var baseRawMap: [String: RawComponentEntry] = [:]
    private(set) var overlayUpserts: [String: RawComponentEntry] = [:]
    private(set) var overlayDeletions: Set<String> = []
    private var usedComponents: Set<String> = []
    private var cachedSubtlexFrequencies: [String: Double]?
    private var scriptClassCache: [String: ScriptClass] = [:]
    private var decompositionPartsCache: [DecompositionPartsCacheKey: [String]] = [:]

    var hasOverlayChanges: Bool {
        !overlayUpserts.isEmpty || !overlayDeletions.isEmpty
    }

    var baseDictionaryFingerprint: String {
        let keys = baseRawMap.keys.sorted()
        return "entries:\(keys.count);first:\(keys.first ?? "");last:\(keys.last ?? "")"
    }

    var addedCharacters: [String] {
        overlayUpserts.keys
            .filter { baseRawMap[$0] == nil && !overlayDeletions.contains($0) }
            .sorted()
    }

    var changedCharacters: [String] {
        overlayUpserts.keys
            .filter { !overlayDeletions.contains($0) }
            .sorted()
    }

    func loadFromBundle() throws {
        guard let url = Bundle.main.url(forResource: "enhanced_component_map_with_etymology", withExtension: "json") else {
            throw NSError(domain: "Radix", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing component map JSON in app bundle."])
        }
        try loadFromURL(url)
    }

    func loadFromURL(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        let raw = try JSONDecoder().decode([String: RawComponentEntry].self, from: data)
        baseRawMap = raw
        overlayUpserts = [:]
        overlayDeletions = []
        activeDatasetURL = url
        rebuildCurrentMap()
    }

    func loadFromRawMap(_ raw: [String: RawComponentEntry]) {
        baseRawMap = raw
        overlayUpserts = [:]
        overlayDeletions = []
        rebuildCurrentMap()
    }

    func entry(for character: String) -> RawComponentEntry? {
        rawMap[character]
    }

    func baseEntry(for character: String) -> RawComponentEntry? {
        baseRawMap[character]
    }

    /// Additive insert — only adds if the character is not already in the overlay.
    func addEntry(character: String, entry: RawComponentEntry) {
        guard overlayUpserts[character] == nil else { return }
        overlayDeletions.remove(character)
        overlayUpserts[character] = entry
        rebuildCurrentMap()
    }

    func replaceEntry(character: String, entry: RawComponentEntry) {
        overlayDeletions.remove(character)
        if baseRawMap[character] == entry {
            overlayUpserts.removeValue(forKey: character)
        } else {
            overlayUpserts[character] = entry
        }
        rebuildCurrentMap()
    }

    func setRawEntryWithoutRebuild(character: String, entry: RawComponentEntry) {
        overlayDeletions.remove(character)
        if baseRawMap[character] == entry {
            overlayUpserts.removeValue(forKey: character)
        } else {
            overlayUpserts[character] = entry
        }
    }

    func deleteEntry(character: String) {
        if baseRawMap[character] != nil {
            overlayDeletions.insert(character)
        }
        overlayUpserts.removeValue(forKey: character)
        rebuildCurrentMap()
    }

    func restoreEntryFromBase(character: String) {
        overlayUpserts.removeValue(forKey: character)
        overlayDeletions.remove(character)
        rebuildCurrentMap()
    }

    func applyOverlay(_ overlay: DictionaryOverlayPackage) {
        let deleted = Set(overlay.deletions)
        overlayDeletions = deleted
        overlayUpserts = overlay.upserts.filter { !deleted.contains($0.key) }
        rebuildCurrentMap()
    }

    func overlayPackage() -> DictionaryOverlayPackage {
        DictionaryOverlayPackage(
            schemaVersion: 2,
            upserts: overlayUpserts,
            deletions: overlayDeletions.sorted()
        )
    }

    func overlayPatchPackage(updatedAt: Date = Date()) -> DictionaryOverlayPatchPackage {
        var customEntries: [String: RawComponentEntry] = [:]
        var patches: [DictionaryEntryPatch] = []

        for (character, entry) in overlayUpserts {
            guard character.count == 1 else { continue }
            guard let baseEntry = baseRawMap[character] else {
                customEntries[character] = entry
                continue
            }

            let patch = makePatch(character: character, base: baseEntry, edited: entry, updatedAt: updatedAt)
            if patch.relatedCharacters != nil || !patch.meta.isEmpty {
                patches.append(patch)
            }
        }

        return DictionaryOverlayPatchPackage(
            schemaVersion: 3,
            customEntries: customEntries,
            patches: patches.sorted { $0.character < $1.character },
            deletions: overlayDeletions.sorted()
        )
    }

    func overlayPackage(from patchPackage: DictionaryOverlayPatchPackage) -> DictionaryOverlayPackage {
        var upserts = patchPackage.customEntries.filter { character, _ in
            character.count == 1 && !patchPackage.deletions.contains(character)
        }

        for patch in patchPackage.patches where !patchPackage.deletions.contains(patch.character) {
            guard patch.character.count == 1,
                  let baseEntry = baseRawMap[patch.character] else {
                continue
            }
            let entry = applyPatch(patch, to: baseEntry)
            if entry != baseEntry {
                upserts[patch.character] = entry
            }
        }

        return DictionaryOverlayPackage(
            schemaVersion: 3,
            upserts: upserts,
            deletions: patchPackage.deletions.filter { $0.count == 1 }.sorted()
        )
    }

    func saveOverlay(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(overlayPackage())
        try data.write(to: url, options: .atomic)
    }

    func saveRawMap(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(rawMap)
        try data.write(to: url, options: .atomic)
    }

    static func makeOverlay(base: [String: RawComponentEntry], effective: [String: RawComponentEntry]) -> DictionaryOverlayPackage {
        var upserts: [String: RawComponentEntry] = [:]
        var deletions: [String] = []

        for (character, entry) in effective where base[character] != entry {
            upserts[character] = entry
        }

        for character in base.keys where effective[character] == nil {
            deletions.append(character)
        }

        return DictionaryOverlayPackage(schemaVersion: 2, upserts: upserts, deletions: deletions.sorted())
    }

    private func rebuildCurrentMap() {
        var effective = baseRawMap
        for character in overlayDeletions {
            effective.removeValue(forKey: character)
        }
        for (character, entry) in overlayUpserts {
            if let baseEntry = baseRawMap[character] {
                effective[character] = mergedOverlayEntry(entry, onto: baseEntry)
            } else {
                effective[character] = entry
            }
        }
        rawMap = effective
        rebuildIndices(from: effective)
    }

    // Keep newer metadata fields from the bundled dictionary when older overlays
    // don't carry them yet. This prevents legacy mobile edits from wiping fields
    // like `variant` that were added later.
    private func mergedOverlayEntry(_ overlay: RawComponentEntry, onto base: RawComponentEntry) -> RawComponentEntry {
        let baseMeta = base.meta
        let overlayMeta = overlay.meta
        let mergedPinyin = overlayMeta.pinyin ?? baseMeta.pinyin
        let mergedDefinition = overlayMeta.definition ?? baseMeta.definition
        let mergedDecomposition = overlayMeta.decomposition ?? baseMeta.decomposition
        let mergedIDC = overlayMeta.idc ?? baseMeta.idc
        let mergedRadical = overlayMeta.radical ?? baseMeta.radical
        let mergedStrokes = overlayMeta.strokes ?? baseMeta.strokes
        let mergedVariant = overlayMeta.variant ?? baseMeta.variant
        let mergedCompounds = overlayMeta.compounds ?? baseMeta.compounds
        let mergedEtymology = overlayMeta.etymology ?? baseMeta.etymology
        let mergedNotes = overlayMeta.notes ?? baseMeta.notes
        // Union additional variants, preserving order and removing duplicates
        var mergedAdditional: [String] = baseMeta.additionalVariants ?? []
        for v in overlayMeta.additionalVariants ?? [] where !mergedAdditional.contains(v) {
            mergedAdditional.append(v)
        }

        let mergedMeta = RawMeta(
            variant: mergedVariant,
            additionalVariants: mergedAdditional.isEmpty ? nil : mergedAdditional,
            pinyin: mergedPinyin,
            definition: mergedDefinition,
            decomposition: mergedDecomposition,
            idc: mergedIDC,
            radical: mergedRadical,
            strokes: mergedStrokes,
            compounds: mergedCompounds,
            etymology: mergedEtymology,
            notes: mergedNotes
        )

        return RawComponentEntry(
            relatedCharacters: overlay.relatedCharacters,
            meta: mergedMeta
        )
    }

    private func makePatch(character: String, base: RawComponentEntry, edited: RawComponentEntry, updatedAt: Date) -> DictionaryEntryPatch {
        let baseMeta = base.meta
        let editedMeta = edited.meta
        let metaPatch = RawMetaPatch(
            variant: editedMeta.variant != baseMeta.variant ? editedMeta.variant : nil,
            additionalVariants: editedMeta.additionalVariants != baseMeta.additionalVariants ? editedMeta.additionalVariants : nil,
            pinyin: editedMeta.pinyin != baseMeta.pinyin ? editedMeta.pinyin : nil,
            definition: editedMeta.definition != baseMeta.definition ? editedMeta.definition : nil,
            decomposition: editedMeta.decomposition != baseMeta.decomposition ? editedMeta.decomposition : nil,
            idc: editedMeta.idc != baseMeta.idc ? editedMeta.idc : nil,
            radical: editedMeta.radical != baseMeta.radical ? editedMeta.radical : nil,
            strokes: editedMeta.strokes != baseMeta.strokes ? editedMeta.strokes : nil,
            compounds: editedMeta.compounds != baseMeta.compounds ? editedMeta.compounds : nil,
            etymology: editedMeta.etymology != baseMeta.etymology ? editedMeta.etymology : nil,
            notes: editedMeta.notes != baseMeta.notes ? editedMeta.notes : nil
        )

        return DictionaryEntryPatch(
            character: character,
            relatedCharacters: edited.relatedCharacters != base.relatedCharacters ? edited.relatedCharacters : nil,
            meta: metaPatch,
            updatedAt: updatedAt
        )
    }

    private func applyPatch(_ patch: DictionaryEntryPatch, to base: RawComponentEntry) -> RawComponentEntry {
        let baseMeta = base.meta
        let patchMeta = patch.meta
        let meta = RawMeta(
            variant: patchMeta.variant ?? baseMeta.variant,
            additionalVariants: patchMeta.additionalVariants ?? baseMeta.additionalVariants,
            pinyin: patchMeta.pinyin ?? baseMeta.pinyin,
            definition: patchMeta.definition ?? baseMeta.definition,
            decomposition: patchMeta.decomposition ?? baseMeta.decomposition,
            idc: patchMeta.idc ?? baseMeta.idc,
            radical: patchMeta.radical ?? baseMeta.radical,
            strokes: patchMeta.strokes ?? baseMeta.strokes,
            compounds: patchMeta.compounds ?? baseMeta.compounds,
            etymology: patchMeta.etymology ?? baseMeta.etymology,
            notes: patchMeta.notes ?? baseMeta.notes
        )
        return RawComponentEntry(
            relatedCharacters: patch.relatedCharacters ?? base.relatedCharacters,
            meta: meta
        )
    }

    private func rebuildIndices(from raw: [String: RawComponentEntry]) {
        scriptClassCache.removeAll()
        decompositionPartsCache.removeAll()
        let subtlexFreq = loadSubtlexFrequencies()
        subtlexLoadedCount = subtlexFreq.count

        // 1. Calculate Base Ranks (1-6000)
        let sortedByFreq = subtlexFreq
            .filter { $0.key.count == 1 }
            .sorted { $0.value > $1.value }
            .prefix(6000)
        
        var charToRank: [String: Int] = [:]
        for (index, pair) in sortedByFreq.enumerated() {
            charToRank[pair.key] = index + 1
        }

        var mapped: [String: ComponentItem] = [:]
        mapped.reserveCapacity(raw.count)

        for (character, entry) in raw {
            let meta = entry.meta
            let lookupChar = toSimplified(character)
            let baseRank = charToRank[lookupChar]
            let usage = Set(entry.relatedCharacters.filter { $0.count == 1 }).count
            
            // 2. Assign Tier based on Rank + Utility Adjustment
            var assignedTier = 5
            if let rank = baseRank {
                if rank <= 1500 { assignedTier = 1 }
                else if rank <= 3000 { assignedTier = 2 }
                else if rank <= 4000 { assignedTier = 3 }
                else if rank <= 6000 { assignedTier = 4 }
            }
            
            // Aggressive Utility Promotion: 
            // If a character is a vital component (used in 15+ characters) but has a low frequency, 
            // promote it to Tier 2 to ensure the learner doesn't skip it.
            if assignedTier > 2 && usage >= 15 {
                assignedTier = 2
            }

            let item = ComponentItem(
                id: character,
                character: character,
                variant: meta.variant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                additionalVariants: (meta.additionalVariants ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                pinyin: meta.pinyin?.list ?? [],
                definition: (meta.definition ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                decomposition: (meta.decomposition ?? meta.idc ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                radical: (meta.radical ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                strokes: meta.strokes?.intValue,
                relatedCharacters: entry.relatedCharacters,
                etymologyHint: meta.etymology?.hint?.text ?? "",
                etymologyDetails: meta.etymology?.details?.text ?? "",
                notes: meta.notes?.text ?? "",
                usageCount: usage,
                freqPerMillion: subtlexFreq[lookupChar] ?? 0,
                rank: baseRank,
                tier: assignedTier
            )
            mapped[character] = item
        }

        byCharacter = mapped
        allCharacters = mapped.keys.sorted()
        usedComponents = computeUsedComponents(from: mapped)
    }

    func search(query: String, scriptFilter: ScriptFilter, limit: Int = 300) -> [ComponentItem] {
        if query.isEmpty {
            return allCharacters
                .compactMap { byCharacter[$0] }
                .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
                .prefix(limit)
                .map { $0 }
        }

        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let pinyinQuery = normalizePinyinForSearch(query)

        if normalized.count == 1, let exact = byCharacter[normalized], matchesScriptFilter(item: exact, filter: scriptFilter) {
            return [exact]
        }

        let directCharMatch = byCharacter[query].map { item in
            matchesScriptFilter(item: item, filter: scriptFilter) ? [item] : []
        } ?? []
        let ranked = allCharacters.compactMap { key -> (item: ComponentItem, rank: Int, tokenLen: Int, token: String)? in
            guard let item = byCharacter[key] else { return nil }
            guard matchesScriptFilter(item: item, filter: scriptFilter) else { return nil }

            let tokens = item.pinyin.map(normalizePinyinForSearch).filter { !$0.isEmpty }
            let compact = tokens.joined()

            // Streamlit-like priority: exact pinyin syllable first, then prefix/contains.
            if !pinyinQuery.isEmpty, let exactToken = tokens.first(where: { $0 == pinyinQuery }) {
                return (item, 0, exactToken.count, exactToken)
            }
            if !pinyinQuery.isEmpty, let prefixToken = tokens.first(where: { $0.hasPrefix(pinyinQuery) }) {
                return (item, 1, prefixToken.count, prefixToken)
            }
            if !pinyinQuery.isEmpty, let containsToken = tokens.first(where: { $0.contains(pinyinQuery) }) {
                return (item, 2, containsToken.count, containsToken)
            }
            if !pinyinQuery.isEmpty, compact.contains(pinyinQuery) {
                return (item, 3, compact.count, compact)
            }
            if item.searchableText.contains(normalized) {
                return (item, 4, 999, "")
            }
            return nil
        }
        .sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.tokenLen != rhs.tokenLen { return lhs.tokenLen < rhs.tokenLen }
            
            // Primary tie-breaker: Rank (1-6000). Ranked characters come before unranked (nil).
            let lRank = lhs.item.rank ?? 999999
            let rRank = rhs.item.rank ?? 999999
            if lRank != rRank { return lRank < rRank }
            
            if lhs.item.usageCount != rhs.item.usageCount { return lhs.item.usageCount > rhs.item.usageCount }
            return lhs.item.character < rhs.item.character
        }
        .map(\.item)

        return Array((directCharMatch + ranked).orderedUnique().prefix(limit))
    }

    func related(for character: String, scriptFilter: ScriptFilter, max: Int = 120) -> [ComponentItem] {
        guard let base = byCharacter[character] else { return [] }
        return base.relatedCharacters
            .prefix(max)
            .compactMap { byCharacter[$0] }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
    }

    /// Fallback: find characters whose decomposition contains the given character, even if the base isn't marked as a component.
    func relatedByContainment(for character: String, scriptFilter: ScriptFilter, max: Int = 200) -> [ComponentItem] {
        let results = byCharacter.values
            .filter { $0.character != character && !$0.decomposition.isEmpty }
            .filter { item in
                decompositionParts(from: item.decomposition, excluding: item.character).contains(character)
            }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
            .sorted(by: frequencyThenUsageSort)
        return Array(results.prefix(max))
    }

    /// Full set of characters that contain the given character anywhere in their decomposition.
    func containingCharacters(for character: String, scriptFilter: ScriptFilter, max: Int = 8000) -> [ComponentItem] {
        let results = byCharacter.values
            .filter { $0.character != character && !$0.decomposition.isEmpty }
            .filter { item in
                decompositionParts(from: item.decomposition, excluding: item.character).contains(character)
            }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
            .sorted(by: frequencyThenUsageSort)
        return Array(results.prefix(max))
    }

    func sharedComponentPeers(for character: String, scriptFilter: ScriptFilter, limit: Int = 300) -> [ComponentItem] {
        guard let base = byCharacter[character] else { return [] }
        let parts = Set(decompositionParts(from: base.decomposition, excluding: character))
        guard !parts.isEmpty else { return [] }

        let peers = byCharacter.values
            .filter { $0.character != character && !$0.decomposition.isEmpty }
            .filter { item in
                let compSet = Set(decompositionParts(from: item.decomposition, excluding: item.character))
                return !parts.isDisjoint(with: compSet)
            }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
            .sorted(by: frequencyThenUsageSort)

        return Array(peers.prefix(limit))
    }

    func sharedPeersByComponent(for character: String, scriptFilter: ScriptFilter, perComponentLimit: Int = 120) -> [String: [ComponentItem]] {
        guard let base = byCharacter[character] else { return [:] }
        var parts = Set(decompositionParts(from: base.decomposition, excluding: character))
        // If the character has no decomposition parts, fall back to treating the character itself as a component
        if parts.isEmpty { parts = [character] }

        var result: [String: [ComponentItem]] = [:]
        for comp in parts {
            let matches = byCharacter.values
                .filter { $0.character != character && !$0.decomposition.isEmpty }
                .filter { item in
                    let compSet = Set(decompositionParts(from: item.decomposition, excluding: item.character))
                    return compSet.contains(comp)
                }
                .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
                .sorted(by: frequencyThenUsageSort)

            result[comp] = Array(matches.prefix(perComponentLimit))
        }

        return result
    }

    func components(for character: String, scriptFilter: ScriptFilter) -> [ComponentItem] {
        guard let base = byCharacter[character] else { return [] }
        let parts = decompositionParts(from: base.decomposition, excluding: character)
        return parts.compactMap { byCharacter[$0] }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
    }

    func analyzeStructure(for character: String) -> ComponentStructureAnalysis? {
        guard let base = byCharacter[character] else { return nil }
        let decomposition = base.decomposition
        guard let first = decomposition.first, first == "⿰" || first == "⿱" else { return nil }

        let semantic = base.radical.isEmpty || base.radical == "—" ? nil : base.radical
        let parts = decompositionParts(from: decomposition, excluding: character)

        guard let semantic else {
            return ComponentStructureAnalysis(semantic: nil, phonetic: nil, phoneticPinyin: nil, isSoundMatch: false)
        }

        let phonetic = parts.first(where: { $0 != semantic })
        let phoneticPinyin = phonetic.flatMap { byCharacter[$0]?.pinyin.first }
        let sourcePinyin = base.pinyin.first

        return ComponentStructureAnalysis(
            semantic: semantic,
            phonetic: phonetic,
            phoneticPinyin: phoneticPinyin,
            isSoundMatch: matchesSound(lhs: sourcePinyin, rhs: phoneticPinyin)
        )
    }

    func pronunciationFamily(for character: String, limit: Int = 8) -> [String] {
        guard let analysis = analyzeStructure(for: character),
              let phonetic = analysis.phonetic,
              !phonetic.isEmpty
        else { return [] }

        let out = byCharacter.values
            .filter { $0.character != character && $0.decomposition.contains(phonetic) }
            .sorted(by: frequencyThenUsageSort)
            .map(\.character)
        return Array(out.prefix(limit))
    }

    func semanticFamily(for character: String, limit: Int = 8) -> [String] {
        guard let radical = byCharacter[character]?.radical, !radical.isEmpty, radical != "—" else {
            return []
        }
        let out = byCharacter.values
            .filter { $0.character != character && $0.radical == radical }
            .sorted(by: frequencyThenUsageSort)
            .map(\.character)
        return Array(out.prefix(limit))
    }

    func searchDefinitions(query: String, scriptFilter: ScriptFilter, limit: Int = 120, isStrict: Bool = false) -> [ComponentItem] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return [] }

        return allCharacters.compactMap { key in
            guard let item = byCharacter[key] else { return nil }
            guard matchesScriptFilter(item: item, filter: scriptFilter) else { return nil }
            
            let definition = item.definition.lowercased()
            if isStrict {
                // Use a simple word boundary check for " car " vs "cart"
                // We check if it's the start/end or surrounded by non-alphanumeric chars
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: normalized))\\b"
                if definition.range(of: pattern, options: .regularExpression) != nil {
                    return item
                }
                return nil
            } else {
                return definition.contains(normalized) ? item : nil
            }
        }
        .prefix(limit)
        .map { $0 }
    }

    func hasCharacter(_ character: String) -> Bool {
        byCharacter[character] != nil
    }

    /// Returns all script variants for a character — explicit variants first, then CFTransform fallback.
    func allVariants(for character: String) -> [String] {
        guard let item = byCharacter[character] else { return [] }
        let explicit = item.allVariants.filter { $0 != character && byCharacter[$0] != nil }
        if !explicit.isEmpty { return explicit }
        // Fallback to CFStringTransform
        var result: [String] = []
        let s = toSimplified(character)
        let t = toTraditional(character)
        if s != character, byCharacter[s] != nil { result.append(s) }
        if t != character, byCharacter[t] != nil, !result.contains(t) { result.append(t) }
        return result
    }

    func counterpart(for character: String) -> String? {
        allVariants(for: character).first
    }

    func simplifiedText(_ value: String) -> String {
        toSimplified(value)
    }

    func availableRadicals() -> [String] {
        let radicals = Set(byCharacter.values.map(\.radical).filter { !$0.isEmpty && $0 != "—" })
        return radicals.sorted { lhs, rhs in
            let lhsStrokes = byCharacter[lhs]?.strokes ?? Int.max
            let rhsStrokes = byCharacter[rhs]?.strokes ?? Int.max
            if lhsStrokes != rhsStrokes { return lhsStrokes < rhsStrokes }
            return lhs < rhs
        }
    }

    func availableStructures() -> [String] {
        let structures = Set(byCharacter.values.map { structureKey(for: $0) })
        return structures.sorted()
    }

    func structureKey(for item: ComponentItem) -> String {
        guard let first = item.decomposition.first, idcChars.contains(first) else {
            return "None"
        }
        return String(first)
    }

    func isSimplifiedForGrid(_ value: String) -> Bool {
        scriptClass(for: value) != .traditionalOnly
    }

    func isTraditionalForGrid(_ value: String) -> Bool {
        scriptClass(for: value) != .simplifiedOnly
    }

    func isUsedComponent(_ character: String) -> Bool {
        usedComponents.contains(character)
    }

    func matchesScriptFilter(item: ComponentItem, filter: ScriptFilter) -> Bool {
        switch filter {
        case .any:
            return true
        case .simplified:
            return isSimplified(item.character)
        case .traditional:
            return isTraditional(item.character)
        }
    }

    // MARK: - Script Classification

    private enum ScriptClass {
        case simplifiedOnly   // has a variant and fewer strokes than it → simplified form
        case traditionalOnly  // has a variant and more strokes than it → traditional form
        case both             // no variant, or strokes equal/missing → neutral (both scripts)
    }

    private struct DecompositionPartsCacheKey: Hashable {
        let decomposition: String
        let excluding: String
    }

    /// Primary classifier. Uses the character's own variant + stroke data first;
    /// falls back to Apple CFStringTransform when the data is inconclusive.
    private func scriptClass(for value: String) -> ScriptClass {
        if let cached = scriptClassCache[value] {
            return cached
        }

        let resolved: ScriptClass
        guard let item = byCharacter[value] else {
            resolved = scriptClassViaCFTransform(value)
            scriptClassCache[value] = resolved
            return resolved
        }

        let variantChars = item.allVariants.filter { !$0.isEmpty && $0 != value }
        guard !variantChars.isEmpty else {
            // No variants → neutral, exists in both scripts
            scriptClassCache[value] = .both
            return .both
        }

        guard let ownStrokes = item.strokes else {
            resolved = scriptClassViaCFTransform(value)
            scriptClassCache[value] = resolved
            return resolved
        }

        // Collect stroke counts for all variants that are in the dictionary
        let variantStrokes = variantChars.compactMap { byCharacter[$0]?.strokes }
        guard !variantStrokes.isEmpty else {
            // Variants exist but none have stroke data → fall back
            resolved = scriptClassViaCFTransform(value)
            scriptClassCache[value] = resolved
            return resolved
        }

        let minVariantStrokes = variantStrokes.min()!
        let maxVariantStrokes = variantStrokes.max()!

        if ownStrokes < minVariantStrokes {
            scriptClassCache[value] = .simplifiedOnly
            return .simplifiedOnly
        }
        if ownStrokes > maxVariantStrokes {
            scriptClassCache[value] = .traditionalOnly
            return .traditionalOnly
        }
        // Own strokes within variant range → fall back
        resolved = scriptClassViaCFTransform(value)
        scriptClassCache[value] = resolved
        return resolved
    }

    /// Fallback classifier using Apple's Unicode transform tables.
    private func scriptClassViaCFTransform(_ value: String) -> ScriptClass {
        let s = toSimplified(value)
        let t = toTraditional(value)
        if s == value && t != value { return .simplifiedOnly }
        if t == value && s != value { return .traditionalOnly }
        return .both
    }

    private func isSimplified(_ value: String) -> Bool {
        scriptClass(for: value) != .traditionalOnly
    }

    private func isTraditional(_ value: String) -> Bool {
        scriptClass(for: value) != .simplifiedOnly
    }

    private func convert(_ value: String, transform: String) -> String {
        let mutable = NSMutableString(string: value)
        if CFStringTransform(mutable, nil, transform as CFString, false) {
            return String(mutable)
        }
        return value
    }

    private func toSimplified(_ value: String) -> String {
        convertWithFallback(value, transforms: ["Hant-Hans", "Traditional-Simplified", "Any-Hans"])
    }

    private func toTraditional(_ value: String) -> String {
        convertWithFallback(value, transforms: ["Hans-Hant", "Simplified-Traditional", "Any-Hant"])
    }

    private func convertWithFallback(_ value: String, transforms: [String]) -> String {
        for transform in transforms {
            let converted = convert(value, transform: transform)
            if converted != value {
                return converted
            }
        }
        return value
    }

    private func decompositionParts(from decomposition: String, excluding character: String) -> [String] {
        let key = DecompositionPartsCacheKey(decomposition: decomposition, excluding: character)
        if let cached = decompositionPartsCache[key] {
            return cached
        }

        var out: [String] = []
        for ch in decomposition {
            guard !idcChars.contains(ch) else { continue }
            let token = String(ch)
            guard token != character, token != "?", token != "—", byCharacter[token] != nil else { continue }
            if !out.contains(token) {
                out.append(token)
            }
        }
        decompositionPartsCache[key] = out
        return out
    }

    private func matchesSound(lhs: String?, rhs: String?) -> Bool {
        guard let lhs, let rhs, !lhs.isEmpty, !rhs.isEmpty else { return false }
        return normalizePinyin(lhs) == normalizePinyin(rhs)
    }

    private func normalizePinyin(_ value: String) -> String {
        let mutable = NSMutableString(string: value.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let stripped = mutable as String
        return stripped.filter { $0.isLetter }
    }

    private func normalizePinyinForSearch(_ value: String) -> String {
        let mutable = NSMutableString(string: value.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let stripped = mutable as String
        return stripped.filter { $0.isLetter || $0.isNumber }
    }

    private func loadSubtlexFrequencies() -> [String: Double] {
        if let cachedSubtlexFrequencies {
            return cachedSubtlexFrequencies
        }

        if let jsonURL = locateSubtlexJSONURL(),
           let data = try? Data(contentsOf: jsonURL),
           let parsed = try? JSONDecoder().decode([String: Double].self, from: data),
           !parsed.isEmpty {
            cachedSubtlexFrequencies = parsed
            return parsed
        }

        guard let url = locateSubtlexFileURL(),
              let data = try? Data(contentsOf: url) else {
            cachedSubtlexFrequencies = [:]
            return [:]
        }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let gb2312 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
        let content =
            String(data: data, encoding: gb18030) ??
            String(data: data, encoding: gb2312) ??
            String(data: data, encoding: .utf8) ??
            String(decoding: data, as: UTF8.self)
        if content.isEmpty {
            cachedSubtlexFrequencies = [:]
            return [:]
        }

        var out: [String: Double] = [:]
        for line in content.split(separator: "\n") {
            if line.hasPrefix("Character") || line.hasPrefix("Total") {
                continue
            }
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { continue }
            let char = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let freq = Double(parts[2]) ?? 0
            if char.count == 1, freq > 0 {
                out[char] = freq
            }
        }
        cachedSubtlexFrequencies = out
        return out
    }

    private func locateSubtlexFileURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "SUBTLEX-CH-CHR", withExtension: "txt") {
            return direct
        }
        if let txts = Bundle.main.urls(forResourcesWithExtension: "txt", subdirectory: nil),
           let match = txts.first(where: { $0.lastPathComponent.uppercased().contains("SUBTLEX") }) {
            return match
        }
        if let all = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil),
           let match = all.first(where: { $0.lastPathComponent.uppercased().contains("SUBTLEX-CH-CHR") }) {
            return match
        }
        return nil
    }

    private func locateSubtlexJSONURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "subtlex_freq", withExtension: "json") {
            return direct
        }
        if let inResources = Bundle.main.url(forResource: "subtlex_freq", withExtension: "json", subdirectory: "Resources") {
            return inResources
        }
        if let jsons = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil),
           let match = jsons.first(where: { $0.lastPathComponent.lowercased().contains("subtlex_freq") }) {
            return match
        }
        if let jsonsInResources = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Resources"),
           let match = jsonsInResources.first(where: { $0.lastPathComponent.lowercased().contains("subtlex_freq") }) {
            return match
        }
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.lowercased() == "subtlex_freq.json" {
                    return fileURL
                }
            }
        }
        return nil
    }

    private func computeUsedComponents(from data: [String: ComponentItem]) -> Set<String> {
        var used: Set<String> = []
        for item in data.values {
            for ch in item.decomposition where !idcChars.contains(ch) {
                used.insert(String(ch))
            }
        }
        return used
    }

    private func frequencyThenUsageSort(_ lhs: ComponentItem, _ rhs: ComponentItem) -> Bool {
        let lRank = lhs.rank ?? 999999
        let rRank = rhs.rank ?? 999999
        if lRank != rRank { return lRank < rRank }
        
        if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
        return lhs.character < rhs.character
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element: Hashable {
    func orderedUnique() -> [Element] {
        var seen = Set<Element>()
        var out: [Element] = []
        for item in self where !seen.contains(item) {
            seen.insert(item)
            out.append(item)
        }
        return out
    }
}
