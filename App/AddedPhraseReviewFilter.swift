import SwiftUI

extension AddedPhraseReviewFilter {
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
}
