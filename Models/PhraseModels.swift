import Foundation

enum PhraseReviewStatus: String, Codable, CaseIterable {
    case checked
    case hidden
    case removed
    case completed

    var title: String {
        switch self {
        case .checked: return "Checked"
        case .hidden: return "Hidden"
        case .removed: return "Rejected"
        case .completed: return "Checked"
        }
    }
}

enum PhraseReviewStatusTool: String, CaseIterable, Identifiable {
    case removed
    case checked
    case hidden
    case new

    var id: String { rawValue }

    var title: String {
        switch self {
        case .removed: return "Rejected"
        case .checked: return "Checked"
        case .hidden: return "Hidden"
        case .new: return "New"
        }
    }

    var status: PhraseReviewStatus? {
        switch self {
        case .removed: return .removed
        case .checked: return .checked
        case .hidden: return .hidden
        case .new: return nil
        }
    }

    static func tool(for status: PhraseReviewStatus?) -> PhraseReviewStatusTool {
        switch status {
        case .removed: return .removed
        case .checked: return .checked
        case .hidden: return .hidden
        case .completed: return .checked
        case nil: return .new
        }
    }

    static func nextStatus(after status: PhraseReviewStatus?) -> PhraseReviewStatus? {
        switch status {
        case nil: return .removed
        case .removed: return .checked
        case .checked, .completed: return .hidden
        case .hidden: return nil
        }
    }
}

enum PhraseReviewStatusCycleAction {
    case previewOnly
    case apply(PhraseReviewStatus?)
}

enum AddedPhraseReviewFilter: String, CaseIterable, Identifiable {
    case new
    case checked
    case hidden
    case removed
    case all

    var id: String { rawValue }

    static let menuCases: [AddedPhraseReviewFilter] = [.removed, .checked, .hidden, .new, .all]

    var title: String {
        switch self {
        case .new: return "New"
        case .checked: return "Checked"
        case .hidden: return "Hidden"
        case .removed: return "Rejected"
        case .all: return "All"
        }
    }

    func includes(_ phrase: PhraseItem) -> Bool {
        switch self {
        case .new: return phrase.reviewStatus == nil
        case .checked: return phrase.reviewStatus == .checked || phrase.reviewStatus == .completed
        case .hidden: return phrase.reviewStatus == .hidden
        case .removed: return phrase.reviewStatus == .removed
        case .all: return true
        }
    }

    static func filter(for status: PhraseReviewStatus?) -> AddedPhraseReviewFilter {
        switch status {
        case .checked: return .checked
        case .hidden: return .hidden
        case .removed: return .removed
        case .completed: return .checked
        case nil: return .new
        }
    }

    var tool: PhraseReviewStatusTool? {
        switch self {
        case .removed: return .removed
        case .checked: return .checked
        case .hidden: return .hidden
        case .new: return .new
        case .all: return nil
        }
    }
}

enum AddedPhraseReviewRules {
    static func statusMessage(_ status: PhraseReviewStatus?, word: String) -> String {
        switch status {
        case .checked: return "\(word) checked."
        case .hidden: return "\(word) hidden from phrase lists, still available on pages."
        case .removed: return "\(word) rejected as not a phrase."
        case .completed: return "\(word) checked."
        case nil: return "\(word) restored to New."
        }
    }

    static func reviewSortPredicate(_ lhs: PhraseItem, _ rhs: PhraseItem) -> Bool {
        if lhs.word.count != rhs.word.count { return lhs.word.count < rhs.word.count }

        let leftKey = sortKey(primary: lhs.pinyin, fallback: lhs.word)
        let rightKey = sortKey(primary: rhs.pinyin, fallback: rhs.word)
        let pinyinOrder = leftKey.localizedStandardCompare(rightKey)
        if pinyinOrder != .orderedSame { return pinyinOrder == .orderedAscending }

        let lhsDate = lhs.lastReviewedAt ?? lhs.addedAt ?? .distantPast
        let rhsDate = rhs.lastReviewedAt ?? rhs.addedAt ?? .distantPast
        return lhsDate > rhsDate
    }

    private static func sortKey(primary: String, fallback: String) -> String {
        let value = primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : primary
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct PhraseReviewStatusCycleState {
    private(set) var lastInteractedID: String?
    private(set) var activeTool: PhraseReviewStatusTool?

    mutating func action(
        for id: String,
        currentStatus: PhraseReviewStatus?,
        selectedTool: PhraseReviewStatusTool? = nil
    ) -> PhraseReviewStatusCycleAction {
        defer { lastInteractedID = id }

        if let selectedTool {
            activeTool = selectedTool
            if lastInteractedID == id {
                let nextStatus = PhraseReviewStatusTool.nextStatus(after: currentStatus)
                activeTool = PhraseReviewStatusTool.tool(for: nextStatus)
                return .apply(nextStatus)
            }
            return .apply(selectedTool.status)
        }

        if let activeTool, lastInteractedID != id {
            return .apply(activeTool.status)
        }

        guard lastInteractedID == id else { return .previewOnly }
        let nextStatus = PhraseReviewStatusTool.nextStatus(after: currentStatus)
        activeTool = PhraseReviewStatusTool.tool(for: nextStatus)
        return .apply(nextStatus)
    }

    mutating func setActiveTool(_ tool: PhraseReviewStatusTool?) {
        activeTool = tool
    }

    mutating func resetPreview() {
        lastInteractedID = nil
    }
}

struct PhraseItem: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let word: String
    let pinyin: String
    let meanings: String
    let notes: String
    let addedAt: Date?
    let reviewStatus: PhraseReviewStatus?
    let lastReviewedAt: Date?

    init(
        word: String,
        pinyin: String,
        meanings: String,
        notes: String = "",
        addedAt: Date? = nil,
        reviewStatus: PhraseReviewStatus? = nil,
        lastReviewedAt: Date? = nil
    ) {
        self.id = word
        self.word = word
        self.pinyin = pinyin
        self.meanings = meanings
        self.notes = notes
        self.addedAt = addedAt
        self.reviewStatus = reviewStatus
        self.lastReviewedAt = lastReviewedAt
    }

    enum CodingKeys: String, CodingKey {
        case word, pinyin, meanings, notes
        case addedAt = "added_at"
        case reviewStatus = "review_status"
        case lastReviewedAt = "last_reviewed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        word = try c.decode(String.self, forKey: .word)
        pinyin = try c.decode(String.self, forKey: .pinyin)
        meanings = try c.decode(String.self, forKey: .meanings)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt)
        reviewStatus = try c.decodeIfPresent(PhraseReviewStatus.self, forKey: .reviewStatus)
        lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        id = word
    }

    var isNewAddedPhrase: Bool {
        reviewStatus == nil
    }

    var isActivePhrase: Bool {
        reviewStatus != .removed
    }

    var isVisibleInPhraseLibrary: Bool {
        reviewStatus != .hidden && reviewStatus != .removed
    }
}

enum PhraseLengthRule {
    static let allOption: Int? = nil
    static let minimumLength = 2
    static let overflowBucket = 7
    static let filterOptions: [Int?] = [allOption, 2, 3, 4, 5, 6, overflowBucket]

    static func label(for length: Int?) -> String {
        guard let length else { return "All" }
        return length >= overflowBucket ? "\(overflowBucket)+" : "\(length)"
    }

    static func cacheKey(for length: Int?) -> String {
        guard let length else { return "all" }
        return length >= overflowBucket ? "\(overflowBucket)plus" : String(length)
    }

    static func matches(word: String, selectedLength: Int?) -> Bool {
        guard let selectedLength else { return true }
        return selectedLength >= overflowBucket
            ? word.count >= overflowBucket
            : word.count == selectedLength
    }

    static func lookupLengths(selectedLength: Int?, maxPhraseLength: Int) -> [Int] {
        guard let selectedLength else {
            return Array(minimumLength...max(minimumLength, maxPhraseLength))
        }
        if selectedLength >= overflowBucket {
            return Array(overflowBucket...max(overflowBucket, maxPhraseLength))
        }
        return [selectedLength]
    }
}

enum PhraseResultRules {
    static func pinyinSortPredicate(_ lhs: PhraseItem, _ rhs: PhraseItem) -> Bool {
        let lhsPinyin = PinyinSearchNormalizer.normalizedCompactQuery(lhs.pinyin)
        let rhsPinyin = PinyinSearchNormalizer.normalizedCompactQuery(rhs.pinyin)
        if lhsPinyin != rhsPinyin { return lhsPinyin < rhsPinyin }
        if lhs.pinyin != rhs.pinyin { return lhs.pinyin < rhs.pinyin }
        return lhs.word < rhs.word
    }

    static func sortedByPinyin(_ phrases: [PhraseItem]) -> [PhraseItem] {
        phrases.sorted(by: pinyinSortPredicate)
    }

    static func mergedUniqueByWord(primary: [PhraseItem], secondary: [PhraseItem]) -> [PhraseItem] {
        var seen = Set<String>()
        var output: [PhraseItem] = []
        for item in primary + secondary where seen.insert(item.word).inserted {
            output.append(item)
        }
        return sortedByPinyin(output)
    }
}

struct StudyGridEntry: Identifiable {
    let id: String
    let character: String
    let pinyin: String
    let isFavoriteCharacter: Bool
}

struct StudyReviewTile: Identifiable {
    let id: String
    let kind: Kind

    enum Kind {
        case phrase(StudyPhraseRowData)
        case character(StudyGridEntry)
    }

    var pinyin: String {
        switch kind {
        case .phrase(let row): return row.phrase.pinyin
        case .character(let entry): return entry.pinyin
        }
    }

    var sortText: String {
        switch kind {
        case .phrase(let row): return row.phrase.word
        case .character(let entry): return entry.character
        }
    }

    static func phraseTile(_ row: StudyPhraseRowData) -> StudyReviewTile {
        StudyReviewTile(id: "phraseTile:\(row.id)", kind: .phrase(row))
    }

    static func characterTile(_ entry: StudyGridEntry) -> StudyReviewTile {
        StudyReviewTile(id: "characterTile:\(entry.id)", kind: .character(entry))
    }
}

struct StudyPhraseRowData: Identifiable {
    let phrase: PhraseItem
    let marker: StudyPhraseMarker

    var id: String { "\(marker.idPrefix):\(phrase.word)" }
}

enum StudyPhraseMarker {
    case favorite
    case recent

    var idPrefix: String {
        switch self {
        case .favorite: return "phrase"
        case .recent: return "recentPhrase"
        }
    }
}

enum StudyReviewRules {
    static func reviewTileSortPredicate(_ lhs: StudyReviewTile, _ rhs: StudyReviewTile) -> Bool {
        let leftPinyin = sortPinyin(lhs.pinyin)
        let rightPinyin = sortPinyin(rhs.pinyin)
        if leftPinyin != rightPinyin { return leftPinyin < rightPinyin }
        return lhs.sortText < rhs.sortText
    }

    static func phraseMarkerSortPredicate(
        _ lhs: (phrase: PhraseItem, marker: StudyPhraseMarker),
        _ rhs: (phrase: PhraseItem, marker: StudyPhraseMarker)
    ) -> Bool {
        let leftPinyin = sortPinyin(lhs.phrase.pinyin)
        let rightPinyin = sortPinyin(rhs.phrase.pinyin)
        if leftPinyin != rightPinyin { return leftPinyin < rightPinyin }
        return lhs.phrase.word < rhs.phrase.word
    }

    private static func sortPinyin(_ pinyin: String) -> String {
        pinyin
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
