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
    private(set) var byCharacter: [String: ComponentItem] = [:]
    private(set) var allCharacters: [String] = []
    private(set) var subtlexLoadedCount: Int = 0
    private(set) var activeDatasetURL: URL?
    private(set) var rawMap: [String: RawComponentEntry] = [:]
    private(set) var baseRawMap: [String: RawComponentEntry] = [:]
    private(set) var overlayUpserts: [String: RawComponentEntry] = [:]
    private(set) var overlayDeletions: Set<String> = []
    private var usedComponents: Set<String> = []
    private var knownCharacters: Set<String> = []
    private var frequencyProvider = ComponentFrequencyProvider()
    private var scriptClassifier = ComponentScriptClassifier()
    private var decompositionParser = ComponentDecompositionParser()

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

            let patch = ComponentOverlayBuilder.makePatch(character: character, base: baseEntry, edited: entry, updatedAt: updatedAt)
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
            let entry = ComponentOverlayBuilder.applyPatch(patch, to: baseEntry)
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
        ComponentOverlayBuilder.makeOverlay(base: base, effective: effective)
    }

    private func rebuildCurrentMap() {
        var effective = baseRawMap
        for character in overlayDeletions {
            effective.removeValue(forKey: character)
        }
        for (character, entry) in overlayUpserts {
            if let baseEntry = baseRawMap[character] {
                effective[character] = ComponentOverlayBuilder.mergedOverlayEntry(entry, onto: baseEntry)
            } else {
                effective[character] = entry
            }
        }
        rawMap = effective
        rebuildIndices(from: effective)
    }

    private func rebuildIndices(from raw: [String: RawComponentEntry]) {
        scriptClassifier.reset()
        decompositionParser.reset()
        let subtlexFreq = frequencyProvider.subtlexFrequencies()
        let snapshot = ComponentIndexBuilder.build(from: raw, frequencies: subtlexFreq)
        byCharacter = snapshot.byCharacter
        allCharacters = snapshot.allCharacters
        knownCharacters = snapshot.knownCharacters
        usedComponents = snapshot.usedComponents
        subtlexLoadedCount = snapshot.subtlexLoadedCount
    }

    func search(query: String, scriptFilter: ScriptFilter, limit: Int = 300) -> [ComponentItem] {
        ComponentSearchEngine.search(
            query: query,
            allCharacters: allCharacters,
            byCharacter: byCharacter,
            limit: limit
        ) { matchesScriptFilter(item: $0, filter: scriptFilter) }
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
        ComponentSearchEngine.searchDefinitions(
            query: query,
            allCharacters: allCharacters,
            byCharacter: byCharacter,
            limit: limit,
            isStrict: isStrict
        ) { matchesScriptFilter(item: $0, filter: scriptFilter) }
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

    func traditionalText(_ value: String) -> String {
        toTraditional(value)
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
        decompositionParser.structureKey(for: item.decomposition)
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

    private func scriptClass(for value: String) -> ComponentScriptClass {
        scriptClassifier.scriptClass(for: value, in: byCharacter)
    }

    private func isSimplified(_ value: String) -> Bool {
        scriptClass(for: value) != .traditionalOnly
    }

    private func isTraditional(_ value: String) -> Bool {
        scriptClass(for: value) != .simplifiedOnly
    }

    private func toSimplified(_ value: String) -> String {
        ScriptTextConverter.simplified(value)
    }

    private func toTraditional(_ value: String) -> String {
        ScriptTextConverter.traditional(value)
    }

    private func decompositionParts(from decomposition: String, excluding character: String) -> [String] {
        decompositionParser.parts(
            from: decomposition,
            excluding: character,
            knownCharacters: knownCharacters
        )
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

    private func frequencyThenUsageSort(_ lhs: ComponentItem, _ rhs: ComponentItem) -> Bool {
        let lRank = lhs.rank ?? 999999
        let rRank = rhs.rank ?? 999999
        if lRank != rRank { return lRank < rRank }
        
        if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
        return lhs.character < rhs.character
    }
}
