import Foundation

struct PhraseItem: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let word: String
    let pinyin: String
    let meanings: String
    let addedAt: Date?

    init(word: String, pinyin: String, meanings: String, addedAt: Date? = nil) {
        self.id = word
        self.word = word
        self.pinyin = pinyin
        self.meanings = meanings
        self.addedAt = addedAt
    }

    enum CodingKeys: String, CodingKey {
        case word, pinyin, meanings
        case addedAt = "added_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        word = try c.decode(String.self, forKey: .word)
        pinyin = try c.decode(String.self, forKey: .pinyin)
        meanings = try c.decode(String.self, forKey: .meanings)
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt)
        id = word
    }
}
