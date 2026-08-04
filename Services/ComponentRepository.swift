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

final class ComponentRepository {
    private(set) var byCharacter: [String: ComponentItem] = [:]
    private(set) var allCharacters: [String] = []
    private(set) var subtlexLoadedCount: Int = 0
    private(set) var activeDatasetURL: URL?
    private(set) var rawMap: [String: RawComponentEntry] = [:]
    private(set) var baseRawMap: [String: RawComponentEntry] = [:]
    private(set) var overlayUpserts: [String: RawComponentEntry] = [:]
    private(set) var overlayDeletions: Set<String> = []
    var usedComponents: Set<String> = []
    var knownCharacters: Set<String> = []
    private var frequencyProvider = ComponentFrequencyProvider()
    var scriptClassifier = ComponentScriptClassifier()
    var decompositionParser = ComponentDecompositionParser()
    var searchIndex = ComponentSearchIndex()
    var confusablePeerCache: [ScriptFilter: [String: [String]]] = [:]

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
        searchIndex = ComponentSearchIndex(allCharacters: snapshot.allCharacters, byCharacter: snapshot.byCharacter)
        confusablePeerCache.removeAll()
    }

}
