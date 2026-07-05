import SwiftUI

extension DataEditTab {
    var librarySummaryColumns: [GridItem] {
        if sizeClass == .compact {
            return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 2)
        }
        return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 4)
    }

    var pairedBackupActionColumns: [GridItem] {
        let minimum: CGFloat = RadixPlatform.isPhone ? 132 : 220
        return Array(repeating: GridItem(.flexible(minimum: minimum), spacing: 10), count: 2)
    }
}
