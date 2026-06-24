import Foundation

/// Search behavior persisted in user profiles.
enum SearchMode: String, CaseIterable, Identifiable, Codable {
    case smart = "Smart"
    case definition = "Definition"

    var id: String { rawValue }
}

enum LineageSortMode: String, CaseIterable, Identifiable {
    case usage = "Usage"
    case frequency = "Frequency"

    var id: String { rawValue }
}

/// Primary route identifiers persisted in portable profiles.
enum AppRoute: String, CaseIterable, Identifiable {
    case search = "Search"
    case capture = "Capture"
    case lineage = "Lineage"
    case aiLink = "AI Link"
    case favourites = "Favourites"
    case settings = "Settings"

    var id: String { rawValue }
}

/// Browse workspace tabs persisted in portable profiles.
enum HomeTab: String, CaseIterable, Identifiable {
    case smart = "Smart Search"
    case filter = "Filter"
    case favourites = "Favourites"
    case dataEdit = "DataEdit"

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .smart: return 0
        case .filter: return 1
        case .favourites: return 3
        case .dataEdit: return 5
        }
    }
}

enum SidebarNavigationStyle: String, CaseIterable, Identifiable, Codable {
    case descriptive = "Descriptive"
    case compact = "Compact"

    var id: String { rawValue }
    var displayName: String { rawValue }

    static func fromStoredValue(_ value: String) -> SidebarNavigationStyle? {
        if value == "Full" { return .descriptive }
        return SidebarNavigationStyle(rawValue: value)
    }
}

enum GridSortMode: String, CaseIterable, Identifiable {
    case readingOrder = "Reading Order"
    case componentFrequency = "Components"
    case characterFrequency = "All"

    var id: String { rawValue }
}
