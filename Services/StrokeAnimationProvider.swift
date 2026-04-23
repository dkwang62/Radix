import Foundation
import SQLite3

private let SQLITE_TRANSIENT_STROKES = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

private protocol StrokeDataLookup: AnyObject {
    func strokeJSON(for character: String) -> String?
}

final class CharacterStrokeRepository: StrokeDataLookup, @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()

    init() {
        guard let url = Bundle.main.url(forResource: "character_strokes", withExtension: "db") else {
            strokeDebugLog("Missing bundled character_strokes.db")
            return
        }

        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            strokeDebugLog("Unable to open character_strokes.db")
            db = nil
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func strokeJSON(for character: String) -> String? {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let db else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT data FROM strokes WHERE character = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let dataPointer = sqlite3_column_text(statement, 0) else {
            return nil
        }

        let json = String(cString: dataPointer)
        guard StrokeCharacterData(jsonString: json) != nil else {
            strokeDebugLog("Invalid stroke JSON for \(trimmed)")
            return nil
        }

        return json
    }
}

final class GeneratedStrokeRepository: StrokeDataLookup, @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()

    init(fileManager: FileManager = .default) {
        guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            strokeDebugLog("Unable to locate Documents directory for generated stroke cache")
            return
        }

        let url = directory.appendingPathComponent("user_character_strokes.db")
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            strokeDebugLog("Unable to open generated stroke cache at \(url.path)")
            db = nil
            return
        }

        createTableIfNeeded()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func strokeJSON(for character: String) -> String? {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let db else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT data FROM strokes WHERE character = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            strokeDebugLog("Unable to prepare generated stroke lookup")
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let dataPointer = sqlite3_column_text(statement, 0) else {
            return nil
        }

        let json = String(cString: dataPointer)
        guard StrokeCharacterData(jsonString: json) != nil else {
            strokeDebugLog("Invalid generated stroke JSON for \(trimmed)")
            return nil
        }

        return json
    }

    func storeStrokeJSON(_ json: String, for character: String) {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1,
              StrokeCharacterData(jsonString: json) != nil,
              let db else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        let sql = """
        INSERT OR REPLACE INTO strokes(character, data, generated_at)
        VALUES (?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            strokeDebugLog("Unable to prepare generated stroke insert")
            return
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)
        sqlite3_bind_text(statement, 2, (json as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)

        if sqlite3_step(statement) != SQLITE_DONE {
            strokeDebugLog("Unable to store generated stroke JSON for \(trimmed)")
        }
    }

    private func createTableIfNeeded() {
        guard let db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS strokes (
            character TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            generated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_generated_strokes_character ON strokes(character);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            strokeDebugLog("Unable to create generated stroke cache table")
        }
    }
}

private final class CompositeStrokeRepository: StrokeDataLookup {
    private let bundledRepository: CharacterStrokeRepository
    private let generatedRepository: GeneratedStrokeRepository

    init(bundledRepository: CharacterStrokeRepository, generatedRepository: GeneratedStrokeRepository) {
        self.bundledRepository = bundledRepository
        self.generatedRepository = generatedRepository
    }

    func strokeJSON(for character: String) -> String? {
        bundledRepository.strokeJSON(for: character) ?? generatedRepository.strokeJSON(for: character)
    }
}

private final class CharacterStrokeDecompositionRepository {
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
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("component_map_changes.json")
    }
}

private final class ComponentStrokeSynthesizer {
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

private struct StrokeDecomposition {
    let operatorSymbol: Character
    let children: [StrokeDecomposition]
    let character: String?

    var directCharacter: String? {
        guard children.isEmpty else { return nil }
        return character
    }
}

private struct IDSParser {
    let idcChars: Set<Character>

    func parse(_ value: String) -> StrokeDecomposition? {
        var iterator = Array(value).makeIterator()
        return parseNode(from: &iterator)
    }

    private func parseNode(from iterator: inout IndexingIterator<[Character]>) -> StrokeDecomposition? {
        guard let next = iterator.next() else { return nil }
        if idcChars.contains(next) {
            let arity = operandCount(for: next)
            var children: [StrokeDecomposition] = []
            for _ in 0..<arity {
                guard let child = parseNode(from: &iterator) else { return nil }
                children.append(child)
            }
            return StrokeDecomposition(operatorSymbol: next, children: children, character: nil)
        }
        return StrokeDecomposition(operatorSymbol: " ", children: [], character: String(next))
    }

    private func operandCount(for symbol: Character) -> Int {
        switch symbol {
        case "⿲", "⿳": return 3
        default: return 2
        }
    }
}

private enum SynthesisLayout {
    case leftRight
    case topBottom
    case leftMiddleRight
    case topMiddleBottom

    init?(_ symbol: Character) {
        switch symbol {
        case "⿰": self = .leftRight
        case "⿱": self = .topBottom
        case "⿲": self = .leftMiddleRight
        case "⿳": self = .topMiddleBottom
        default: return nil
        }
    }

    func slots(for children: [StrokeDecomposition]) -> [StrokeSlot] {
        switch self {
        case .leftRight:
            let firstComponent = children.first?.directCharacter
            if firstComponent == "馬" {
                return [
                    StrokeSlot(minX: 28, maxX: 500, minY: -84, maxY: 860),
                    StrokeSlot(minX: 548, maxX: 988, minY: -84, maxY: 860)
                ]
            }
            if Self.narrowLeftComponents.contains(firstComponent ?? "") {
                return [
                    StrokeSlot(minX: 36, maxX: 360, minY: -84, maxY: 860),
                    StrokeSlot(minX: 456, maxX: 988, minY: -84, maxY: 860)
                ]
            }
            return [
                StrokeSlot(minX: 36, maxX: 480, minY: -84, maxY: 860),
                StrokeSlot(minX: 544, maxX: 988, minY: -84, maxY: 860)
            ]
        case .topBottom:
            return [
                StrokeSlot(minX: 160, maxX: 864, minY: 520, maxY: 868),
                StrokeSlot(minX: 96, maxX: 928, minY: -92, maxY: 560)
            ]
        case .leftMiddleRight:
            return [
                StrokeSlot(minX: 32, maxX: 336, minY: -84, maxY: 860),
                StrokeSlot(minX: 360, maxX: 664, minY: -84, maxY: 860),
                StrokeSlot(minX: 688, maxX: 992, minY: -84, maxY: 860)
            ]
        case .topMiddleBottom:
            return [
                StrokeSlot(minX: 220, maxX: 804, minY: 512, maxY: 868),
                StrokeSlot(minX: 128, maxX: 896, minY: 184, maxY: 560),
                StrokeSlot(minX: 128, maxX: 896, minY: -92, maxY: 284)
            ]
        }
    }

    private static let narrowLeftComponents: Set<String> = [
        "亻", "彳", "氵", "扌", "忄", "山", "口", "女", "木", "日", "月", "讠", "言"
    ]
}

private struct StrokeSlot {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double

    func transform(_ point: StrokePoint, from sourceBounds: StrokeBounds) -> StrokePoint {
        let x = minX + ((point.x - sourceBounds.minX) / sourceBounds.width) * (maxX - minX)
        let y = minY + ((point.y - sourceBounds.minY) / sourceBounds.height) * (maxY - minY)
        return StrokePoint(x: x, y: y)
    }
}

private struct StrokeBounds {
    var minX: Double
    var maxX: Double
    var minY: Double
    var maxY: Double

    static let defaultCanvas = StrokeBounds(minX: 0, maxX: 1024, minY: -124, maxY: 900)

    var width: Double {
        max(maxX - minX, 1)
    }

    var height: Double {
        max(maxY - minY, 1)
    }

    mutating func include(_ point: StrokePoint) {
        minX = min(minX, point.x)
        maxX = max(maxX, point.x)
        minY = min(minY, point.y)
        maxY = max(maxY, point.y)
    }
}

private struct StrokeCharacterData: Codable, Equatable {
    var character: String
    var strokes: [String]
    var medians: [[[Double]]]
    var radStrokes: [Int]?

    init(character: String, strokes: [String], medians: [[[Double]]], radStrokes: [Int]?) {
        self.character = character
        self.strokes = strokes
        self.medians = medians
        self.radStrokes = radStrokes
    }

    init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StrokeCharacterData.self, from: data),
              decoded.strokes.count == decoded.medians.count else {
            return nil
        }
        self = decoded
    }

    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    mutating func append(_ other: StrokeCharacterData) {
        let offset = strokes.count
        strokes.append(contentsOf: other.strokes)
        medians.append(contentsOf: other.medians)
        if let otherRadStrokes = other.radStrokes, !otherRadStrokes.isEmpty {
            var merged = radStrokes ?? []
            merged.append(contentsOf: otherRadStrokes.map { $0 + offset })
            radStrokes = merged
        }
    }

    func transformed(to slot: StrokeSlot) -> StrokeCharacterData {
        let bounds = sourceBounds ?? .defaultCanvas
        return StrokeCharacterData(
            character: character,
            strokes: strokes.map { StrokePathTransformer.transform(path: $0, to: slot, sourceBounds: bounds) },
            medians: medians.map { stroke in
                stroke.map { pair in
                    guard pair.count >= 2 else { return pair }
                    let transformed = slot.transform(StrokePoint(x: pair[0], y: pair[1]), from: bounds)
                    return [transformed.x, transformed.y]
                }
            },
            radStrokes: radStrokes
        )
    }

    private var sourceBounds: StrokeBounds? {
        var bounds: StrokeBounds?

        func include(_ point: StrokePoint) {
            if bounds == nil {
                bounds = StrokeBounds(minX: point.x, maxX: point.x, minY: point.y, maxY: point.y)
            } else {
                bounds?.include(point)
            }
        }

        for path in strokes {
            StrokePathTransformer.points(in: path).forEach(include)
        }

        for stroke in medians {
            for pair in stroke where pair.count >= 2 {
                include(StrokePoint(x: pair[0], y: pair[1]))
            }
        }

        return bounds
    }
}

private struct StrokePoint {
    let x: Double
    let y: Double
}

private enum StrokePathTransformer {
    private static let commandArities: [String: Int] = [
        "M": 2, "L": 2, "Q": 4, "C": 6, "Z": 0
    ]

    static func transform(path: String, to slot: StrokeSlot, sourceBounds: StrokeBounds) -> String {
        let tokens = tokenize(path)
        var output: [String] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            guard let arity = commandArities[token] else {
                output.append(token)
                index += 1
                continue
            }

            output.append(token)
            index += 1
            guard arity > 0 else { continue }

            var values: [Double] = []
            for _ in 0..<arity where index < tokens.count {
                values.append(Double(tokens[index]) ?? 0)
                index += 1
            }

            var transformed: [String] = []
            var valueIndex = 0
            while valueIndex + 1 < values.count {
                let point = slot.transform(StrokePoint(x: values[valueIndex], y: values[valueIndex + 1]), from: sourceBounds)
                transformed.append(format(point.x))
                transformed.append(format(point.y))
                valueIndex += 2
            }
            output.append(contentsOf: transformed)
        }

        return output.joined(separator: " ")
    }

    static func points(in path: String) -> [StrokePoint] {
        let tokens = tokenize(path)
        var points: [StrokePoint] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            guard let arity = commandArities[token] else {
                index += 1
                continue
            }

            index += 1
            guard arity > 0 else { continue }

            var values: [Double] = []
            for _ in 0..<arity where index < tokens.count {
                values.append(Double(tokens[index]) ?? 0)
                index += 1
            }

            var valueIndex = 0
            while valueIndex + 1 < values.count {
                points.append(StrokePoint(x: values[valueIndex], y: values[valueIndex + 1]))
                valueIndex += 2
            }
        }

        return points
    }

    private static func tokenize(_ path: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        func flush() {
            guard !current.isEmpty else { return }
            tokens.append(current)
            current = ""
        }

        for scalar in path.unicodeScalars {
            let char = Character(scalar)
            if scalar.properties.isAlphabetic {
                flush()
                tokens.append(String(char))
            } else if scalar.properties.isWhitespace || char == "," {
                flush()
            } else {
                current.append(char)
            }
        }
        flush()
        return tokens
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}

private func strokeDebugLog(_ message: String) {
    #if DEBUG
    print("[StrokeAnimation] \(message)")
    #endif
}
