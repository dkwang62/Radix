import SwiftUI

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

    var icon: String {
        switch self {
        case .new: return "sparkle"
        case .checked: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .all: return "line.3.horizontal.decrease.circle"
        }
    }

    var color: Color {
        switch self {
        case .new: return Color.secondary
        case .checked: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case .completed: return Color.purple
        case .all: return Color.accentColor
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
