import Foundation

public enum ConversationPracticeProgressOutcome: String, Codable, Equatable, Sendable {
    case again
    case good
    case easy
    case correct
    case incorrect

    public var countsAsCompletion: Bool {
        switch self {
        case .good, .easy, .correct:
            return true
        case .again, .incorrect:
            return false
        }
    }
}

public struct ConversationPracticeItemProgress: Codable, Equatable, Identifiable, Sendable {
    public let packID: String
    public let itemID: String
    public private(set) var sentenceExampleID: UUID?
    public private(set) var sentenceKey: String?
    public private(set) var attempts: Int
    public private(set) var completedAttempts: Int
    public private(set) var lastOutcome: ConversationPracticeProgressOutcome
    public private(set) var lastPracticedAt: Date
    public private(set) var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case packID = "pack_id"
        case itemID = "item_id"
        case sentenceExampleID = "sentence_example_id"
        case sentenceKey = "sentence_key"
        case attempts
        case completedAttempts = "completed_attempts"
        case lastOutcome = "last_outcome"
        case lastPracticedAt = "last_practiced_at"
        case completedAt = "completed_at"
    }

    public var id: String {
        Self.identifier(packID: packID, itemID: itemID)
    }

    public var isCompleted: Bool {
        completedAt != nil
    }

    public var progressID: String {
        if let sentenceExampleID {
            return "sentence_id:\(sentenceExampleID.uuidString)"
        }
        if let sentenceKey, !sentenceKey.isEmpty {
            return "sentence_key:\(sentenceKey)"
        }
        return id
    }

    public init(
        packID: String,
        itemID: String,
        sentenceExampleID: UUID? = nil,
        sentenceKey: String? = nil,
        attempts: Int,
        completedAttempts: Int,
        lastOutcome: ConversationPracticeProgressOutcome,
        lastPracticedAt: Date,
        completedAt: Date?
    ) {
        self.packID = packID
        self.itemID = itemID
        self.sentenceExampleID = sentenceExampleID
        self.sentenceKey = Self.cleanSentenceKey(sentenceKey)
        self.attempts = max(0, attempts)
        self.completedAttempts = max(0, completedAttempts)
        self.lastOutcome = lastOutcome
        self.lastPracticedAt = lastPracticedAt
        self.completedAt = completedAt
    }

    public static func identifier(packID: String, itemID: String) -> String {
        "\(packID)#\(itemID)"
    }

    public func matches(_ item: ConversationPracticeItem) -> Bool {
        if let sentenceExampleID, sentenceExampleID == item.sentenceExampleID {
            return true
        }
        if let sentenceKey, !sentenceKey.isEmpty, sentenceKey == item.sentenceKey {
            return true
        }
        return packID == item.setID && itemID == item.id
    }

    public mutating func record(
        _ outcome: ConversationPracticeProgressOutcome,
        practicedAt: Date = Date()
    ) {
        attempts += 1
        lastOutcome = outcome
        lastPracticedAt = practicedAt

        if outcome.countsAsCompletion {
            completedAttempts += 1
            if completedAt == nil {
                completedAt = practicedAt
            }
        }
    }

    public mutating func attachSentenceIdentity(from item: ConversationPracticeItem) {
        if sentenceExampleID == nil {
            sentenceExampleID = item.sentenceExampleID
        }
        if sentenceKey == nil || sentenceKey?.isEmpty == true {
            sentenceKey = Self.cleanSentenceKey(item.sentenceKey)
        }
    }

    private static func cleanSentenceKey(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

public struct ConversationPracticeProgressSnapshot: Codable, Equatable, Sendable {
    public private(set) var records: [ConversationPracticeItemProgress]

    enum CodingKeys: String, CodingKey {
        case records
    }

    public init(records: [ConversationPracticeItemProgress] = []) {
        self.records = Self.uniqueNewest(records)
    }

    public func record(for packID: String, itemID: String) -> ConversationPracticeItemProgress? {
        let id = ConversationPracticeItemProgress.identifier(packID: packID, itemID: itemID)
        return records.first { $0.id == id }
    }

    public func record(for item: ConversationPracticeItem) -> ConversationPracticeItemProgress? {
        records.first { $0.matches(item) }
    }

    public mutating func record(
        packID: String,
        itemID: String,
        outcome: ConversationPracticeProgressOutcome,
        practicedAt: Date = Date()
    ) {
        let id = ConversationPracticeItemProgress.identifier(packID: packID, itemID: itemID)
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].record(outcome, practicedAt: practicedAt)
        } else {
            var progress = ConversationPracticeItemProgress(
                packID: packID,
                itemID: itemID,
                attempts: 0,
                completedAttempts: 0,
                lastOutcome: outcome,
                lastPracticedAt: practicedAt,
                completedAt: nil
            )
            progress.record(outcome, practicedAt: practicedAt)
            records.append(progress)
            records.sort { $0.id < $1.id }
        }
    }

    public mutating func record(
        item: ConversationPracticeItem,
        outcome: ConversationPracticeProgressOutcome,
        practicedAt: Date = Date()
    ) {
        if let index = records.firstIndex(where: { $0.matches(item) }) {
            records[index].attachSentenceIdentity(from: item)
            records[index].record(outcome, practicedAt: practicedAt)
        } else {
            var progress = ConversationPracticeItemProgress(
                packID: item.setID,
                itemID: item.id,
                sentenceExampleID: item.sentenceExampleID,
                sentenceKey: item.sentenceKey,
                attempts: 0,
                completedAttempts: 0,
                lastOutcome: outcome,
                lastPracticedAt: practicedAt,
                completedAt: nil
            )
            progress.record(outcome, practicedAt: practicedAt)
            records.append(progress)
        }
        records = Self.uniqueNewest(records)
    }

    public func summary(for library: ConversationPracticeLibrary) -> ConversationPracticeProgressSummary {
        let matchingRecords = library.items.compactMap { item in
            record(for: item)
        }
        let completed = matchingRecords.filter(\.isCompleted).count
        let lastPracticedAt = matchingRecords.map(\.lastPracticedAt).max()
        return ConversationPracticeProgressSummary(
            packID: library.set.id,
            totalItems: library.items.count,
            completedItems: completed,
            lastPracticedAt: lastPracticedAt
        )
    }

    public func merging(_ imported: ConversationPracticeProgressSnapshot?) -> ConversationPracticeProgressSnapshot {
        guard let imported else { return self }
        return ConversationPracticeProgressSnapshot(records: records + imported.records)
    }

    private static func uniqueNewest(
        _ records: [ConversationPracticeItemProgress]
    ) -> [ConversationPracticeItemProgress] {
        let byID = Dictionary(grouping: records, by: \.progressID)
        return byID.values.compactMap { grouped in
            grouped.max { lhs, rhs in
                lhs.lastPracticedAt < rhs.lastPracticedAt
            }
        }
        .sorted { $0.id < $1.id }
    }
}

public struct ConversationPracticeProgressSummary: Equatable, Sendable {
    public let packID: String
    public let totalItems: Int
    public let completedItems: Int
    public let lastPracticedAt: Date?

    public var completionFraction: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }
}
