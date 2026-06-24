import Foundation

/// Canonical customer-facing vocabulary. Keeping these terms in one place
/// prevents iPhone, iPad, and Mac labels from drifting apart.
enum RadixCopy {
    static let takePhoto = String(localized: "Take Photo")
    static let browse = String(localized: "Browse")
    static let search = String(localized: "Search")
    static let study = String(localized: "Study")
    static let aiLink = String(localized: "AI Link")
    static let myData = String(localized: "My Data")
    static let settings = String(localized: "Settings")

    static let savedPage = String(localized: "Saved Page")
    static let savedPages = String(localized: "Saved Pages")
    static let saveDeviceSnapshot = String(localized: "Save Device Snapshot")
    static let restoreDeviceSnapshot = String(localized: "Restore Device Snapshot")

    static let saveBackup = String(localized: "Save Backup")
    static let mergeBackup = String(localized: "Merge Backup")
    static let replaceMyData = String(localized: "Replace My Data")
    static let backupContents = String(localized: "Backup Contents")

    static let accepted = String(localized: "Accepted")
    static let unreviewed = String(localized: "Unreviewed")
    static let hidden = String(localized: "Hidden")
    static let rejected = String(localized: "Rejected")
}

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
    static let delete = "trash"
    static let copy = "doc.on.doc"
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
        case .scan: return RadixCopy.takePhoto
        case .browse: return RadixCopy.browse
        case .search: return RadixCopy.search
        case .study: return RadixCopy.study
        case .aiLink: return RadixCopy.aiLink
        case .myData: return RadixCopy.myData
        }
    }

    var compactTitle: String {
        switch self {
        case .scan: return "Photo"
        case .aiLink: return "AI"
        default: return title
        }
    }

    var subtitle: String {
        switch self {
        case .scan:
            return "Capture text from camera, photos, files, or paste."
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
