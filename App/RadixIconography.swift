import Foundation

enum RadixIcon {
    static let scan = "camera.viewfinder"
    static let search = "magnifyingglass"
    static let browse = "square.grid.2x2"
    static let study = "star"
    static let aiLink = "wand.and.stars"
    static let myData = "externaldrive"
    static let settings = "gearshape"
    static let help = "lightbulb"
    static let info = "info.circle"
    static let saved = "star.fill"
    static let unsaved = "star"
    static let delete = "trash"
    static let copy = "doc.on.doc"
    static let importFile = "square.and.arrow.down"
    static let exportFile = "square.and.arrow.up"
}

enum RadixNavigationItem: Int, CaseIterable, Identifiable {
    case scan = 0
    case browse = 2
    case search = 1
    case study = 3
    case aiLink = 4
    case myData = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .scan: return "Scan"
        case .browse: return "Browse"
        case .search: return "Search"
        case .study: return "Study"
        case .aiLink: return "AI Link"
        case .myData: return "My Data"
        }
    }

    var compactTitle: String {
        switch self {
        case .aiLink: return "AI"
        default: return title
        }
    }

    var subtitle: String {
        switch self {
        case .scan:
            return "Use a camera, photo, or file to turn real text into a browsable page."
        case .search:
            return "Find characters and phrases by Chinese, pinyin, English meaning, or strokes."
        case .browse:
            return "Explore the dictionary or open saved pages from scans and pasted text."
        case .study:
            return "Return to favorites, recent characters, and pages you want to revisit."
        case .aiLink:
            return "Use repeatable AI actions for phrases, interpretation, translation, and saved pages."
        case .myData:
            return "Your additions can travel between iPhone, iPad, and Mac."
        }
    }

    var icon: String {
        switch self {
        case .scan: return RadixIcon.scan
        case .search: return RadixIcon.search
        case .browse: return RadixIcon.browse
        case .study: return RadixIcon.study
        case .aiLink: return RadixIcon.aiLink
        case .myData: return RadixIcon.myData
        }
    }
}
