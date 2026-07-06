import SwiftUI

extension DataEditTab {
    var librarySummaryColumns: [GridItem] {
        if sizeClass == .compact {
            return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 2)
        }
        return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 4)
    }

}
