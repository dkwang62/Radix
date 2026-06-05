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
        case .completed: return "Completed"
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
        case .checked: return .hidden
        case .hidden, .completed: return nil
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
    case completed
    case all

    var id: String { rawValue }

    static let menuCases: [AddedPhraseReviewFilter] = [.removed, .checked, .hidden, .new, .completed, .all]

    var title: String {
        switch self {
        case .new: return "New"
        case .checked: return "Checked"
        case .hidden: return "Hidden"
        case .removed: return "Rejected"
        case .completed: return "Completed"
        case .all: return "All"
        }
    }

    func includes(_ phrase: PhraseItem) -> Bool {
        switch self {
        case .new: return phrase.reviewStatus == nil
        case .checked: return phrase.reviewStatus == .checked
        case .hidden: return phrase.reviewStatus == .hidden
        case .removed: return phrase.reviewStatus == .removed
        case .completed: return phrase.reviewStatus == .completed
        case .all: return phrase.reviewStatus != .completed
        }
    }

    static func filter(for status: PhraseReviewStatus?) -> AddedPhraseReviewFilter {
        switch status {
        case .checked: return .checked
        case .hidden: return .hidden
        case .removed: return .removed
        case .completed: return .completed
        case nil: return .new
        }
    }

    var tool: PhraseReviewStatusTool? {
        switch self {
        case .removed: return .removed
        case .checked: return .checked
        case .hidden: return .hidden
        case .new: return .new
        case .completed: return nil
        case .all: return nil
        }
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
