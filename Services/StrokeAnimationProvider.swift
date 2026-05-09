import Foundation

/*
 Stroke animation pipeline:
 1. Return bundled HanziWriter JSON from read-only character_strokes.db when available.
 2. Return previously generated JSON from user_character_strokes.db when available.
 3. For missing characters, read IDS decomposition from enhanced_component_map_with_etymology.json.
 4. Synthesis supports conservative 2- and 3-part layouts using standalone component strokes.
 5. Successful live synthesis is persisted into user_character_strokes.db for future lookups.
 6. Unavailable cases return an explanation for the UI and debug logs in DEBUG builds.
 */

enum StrokeAnimationSource: Equatable {
    case bundled
    case generatedStored
    case generatedLive
    case unavailable
}

struct StrokeAnimationResult: Equatable {
    let source: StrokeAnimationSource
    let json: String?
    let explanation: String?

    static func unavailable(_ explanation: String) -> StrokeAnimationResult {
        StrokeAnimationResult(source: .unavailable, json: nil, explanation: explanation)
    }
}

final class StrokeAnimationProvider: @unchecked Sendable {
    static let shared = StrokeAnimationProvider()

    private let bundledStrokeRepository = CharacterStrokeRepository()
    private let generatedStrokeRepository = GeneratedStrokeRepository()
    private let decompositionRepository = CharacterStrokeDecompositionRepository()
    private lazy var strokeLookup = CompositeStrokeRepository(
        bundledRepository: bundledStrokeRepository,
        generatedRepository: generatedStrokeRepository
    )
    private lazy var synthesizer = ComponentStrokeSynthesizer(strokeRepository: strokeLookup)
    private let lock = NSLock()
    private var cache: [String: StrokeAnimationResult] = [:]

    private init() {}

    func animationData(for character: String) -> StrokeAnimationResult {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1 else {
            return .unavailable("Choose one Chinese character to see stroke animation.")
        }

        lock.lock()
        if let cached = cache[trimmed] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result: StrokeAnimationResult
        if let json = bundledStrokeRepository.strokeJSON(for: trimmed) {
            result = StrokeAnimationResult(source: .bundled, json: json, explanation: nil)
        } else if let json = generatedStrokeRepository.strokeJSON(for: trimmed) {
            result = StrokeAnimationResult(
                source: .generatedStored,
                json: json,
                explanation: "Generated from saved components"
            )
        } else if let decomposition = decompositionRepository.decomposition(for: trimmed) {
            let synthesized = synthesizer.synthesize(character: trimmed, decomposition: decomposition)
            if synthesized.source == .generatedLive, let json = synthesized.json {
                generatedStrokeRepository.storeStrokeJSON(json, for: trimmed)
            }
            result = synthesized
        } else {
            result = .unavailable("Unable to synthesize from known components.")
            strokeDebugLog("No decomposition found for \(trimmed)")
        }

        if result.source != .unavailable {
            lock.lock()
            cache[trimmed] = result
            lock.unlock()
        }
        return result
    }
}
