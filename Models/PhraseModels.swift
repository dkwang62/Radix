import Foundation

enum PhraseReviewStatus: String, Codable, CaseIterable {
    case checked
    case hidden
    case removed

    var title: String {
        switch self {
        case .checked: return "Checked"
        case .hidden: return "Hidden"
        case .removed: return "Removed"
        }
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
