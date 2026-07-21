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

enum HistoryStripDisplayPolicy {
    static let visibleItemLimit = 80

    static func shouldShow(route: AppRoute, homeTab: HomeTab, hasItems: Bool) -> Bool {
        guard hasItems else { return false }
        switch route {
        case .search:
            switch homeTab {
            case .smart, .filter, .favourites:
                return true
            case .dataEdit:
                return false
            }
        case .lineage, .favourites:
            return true
        case .capture, .aiLink, .settings:
            return false
        }
    }

    static func visibleItems(from items: [String]) -> [String] {
        Array(items.prefix(visibleItemLimit))
    }
}

enum SidebarNavigationStyle: String, CaseIterable, Identifiable, Codable {
    case descriptive = "Descriptive"
    case compact = "Compact"

    static let defaultStyle: SidebarNavigationStyle = .descriptive

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .descriptive: return "Icons & Labels"
        case .compact: return "Icons Only"
        }
    }

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
