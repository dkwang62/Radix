import Foundation

final class CharacterStrokeDecompositionRepository {
    private let idcChars: Set<Character> = ["⿰", "⿱", "⿲", "⿳", "⿴", "⿵", "⿶", "⿷", "⿸", "⿹", "⿺", "⿻"]
    private let curatedFallbacks: [String: String] = [
        // Keep conservative runtime fallback only where the dictionary uses unsupported IDC.
        "衍": "⿲彳氵亍"
    ]
    private var decompositions: [String: String] = [:]
    private var overlaySignature: Date?

    init() {
        guard let url = Bundle.main.url(forResource: "enhanced_component_map_with_etymology", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: RawComponentEntry].self, from: data) else {
            strokeDebugLog("Missing or unreadable component decomposition data")
            return
        }

        decompositions = raw.compactMapValues { entry in
            let value = (entry.meta.decomposition ?? entry.meta.idc ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        loadUserOverlayIfNeeded(force: true)
    }

    func decomposition(for character: String) -> StrokeDecomposition? {
        if decompositions[character] == nil {
            loadUserOverlayIfNeeded(force: false)
        }
        guard let raw = decompositions[character] ?? curatedFallbacks[character],
              let parsed = IDSParser(idcChars: idcChars).parse(raw),
              parsed.character == nil else {
            return nil
        }
        return parsed
    }

    private func loadUserOverlayIfNeeded(force: Bool) {
        guard let url = userDictionaryOverlayURL else { return }

        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        guard force || modified != overlaySignature else { return }
        overlaySignature = modified

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let overlay = try? JSONDecoder().decode(DictionaryOverlayPackage.self, from: data) else {
            return
        }

        for character in overlay.deletions {
            decompositions.removeValue(forKey: character)
        }

        for (character, entry) in overlay.upserts {
            let value = (entry.meta.decomposition ?? entry.meta.idc ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                decompositions.removeValue(forKey: character)
            } else {
                decompositions[character] = value
            }
        }
    }

    private var userDictionaryOverlayURL: URL? {
        if let projectURL = ProjectLiveDataLocator.file(named: "component_map_changes.json") {
            return projectURL
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("component_map_changes.json")
    }
}

final class ComponentStrokeSynthesizer {
    private let strokeRepository: StrokeDataLookup
    private let maxDepth = 4

    init(strokeRepository: StrokeDataLookup) {
        self.strokeRepository = strokeRepository
    }

    func synthesize(character: String, decomposition: StrokeDecomposition) -> StrokeAnimationResult {
        guard let data = synthesizeData(for: decomposition, depth: 0) else {
            return .unavailable("Unable to synthesize from known components.")
        }

        guard let json = StrokeCharacterData(
            character: character,
            strokes: data.strokeData.strokes,
            medians: data.strokeData.medians,
            radStrokes: data.strokeData.radStrokes
        ).jsonString else {
            strokeDebugLog("Failed to encode synthesized strokes for \(character)")
            return .unavailable("Unable to synthesize from known components.")
        }

        return StrokeAnimationResult(
            source: .generatedLive,
            json: json,
            explanation: "Generated from components \(data.provenance.joined(separator: " + "))"
        )
    }

    private func synthesizeData(for decomposition: StrokeDecomposition, depth: Int) -> SynthesizedStrokeData? {
        guard depth <= maxDepth else {
            strokeDebugLog("Synthesis depth exceeded")
            return nil
        }

        if let component = decomposition.character {
            guard let json = strokeRepository.strokeJSON(for: component),
                  let data = StrokeCharacterData(jsonString: json) else {
                strokeDebugLog("Missing component stroke data for \(component)")
                return nil
            }
            return SynthesizedStrokeData(strokeData: data, provenance: [component])
        }

        guard let layout = SynthesisLayout(decomposition.operatorSymbol) else {
            strokeDebugLog("Unsupported decomposition: \(decomposition.operatorSymbol)")
            return nil
        }
        let slots = layout.slots(for: decomposition.children)
        guard decomposition.children.count == slots.count else {
            strokeDebugLog("Unsupported decomposition arity: \(decomposition.operatorSymbol)")
            return nil
        }

        var merged = StrokeCharacterData(character: "", strokes: [], medians: [], radStrokes: nil)
        var provenance: [String] = []
        for (index, child) in decomposition.children.enumerated() {
            guard let childData = synthesizeData(for: child, depth: depth + 1) else {
                return nil
            }
            provenance.append(contentsOf: childData.provenance)
            merged.append(childData.strokeData.transformed(to: slots[index]))
        }

        return SynthesizedStrokeData(strokeData: merged, provenance: provenance)
    }
}

private struct SynthesizedStrokeData {
    let strokeData: StrokeCharacterData
    let provenance: [String]
}
