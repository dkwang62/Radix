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

    var guideTopic: RadixNavigationGuideTopic? {
        switch self {
        case .browse: return .browse
        case .study: return .study
        case .aiLink: return .aiLink
        case .myData: return .myData
        case .scan, .search: return nil
        }
    }
}

enum RadixNavigationGuideTopic: String, CaseIterable, Identifiable {
    case browse
    case study
    case aiLink
    case myData
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse: return RadixCopy.browse
        case .study: return RadixCopy.study
        case .aiLink: return RadixCopy.aiLink
        case .myData: return RadixCopy.myData
        case .settings: return RadixCopy.settings
        }
    }

    var icon: String {
        switch self {
        case .browse: return RadixIcon.browse
        case .study: return RadixIcon.study
        case .aiLink: return RadixIcon.aiLink
        case .myData: return RadixIcon.myData
        case .settings: return RadixIcon.settings
        }
    }

    var summary: String {
        switch self {
        case .browse:
            return "Look through the Chinese in Radix."
        case .study:
            return "Return to the things you want to remember."
        case .aiLink:
            return "Ask an AI service to help with Chinese material."
        case .myData:
            return "Keep your Radix work safe and move it between devices."
        case .settings:
            return "Choose how Radix behaves and connects to AI services."
        }
    }

    var actions: [RadixNavigationGuideAction] {
        switch self {
        case .browse:
            return [
                RadixNavigationGuideAction(
                    icon: "book.closed",
                    title: "Explore the dictionary",
                    detail: "Browse all characters or narrow them by strokes, component, frequency, and simplified or traditional form."
                ),
                RadixNavigationGuideAction(
                    icon: "square.grid.2x2",
                    title: "Open saved pages",
                    detail: "Return to Chinese captured from a photo, imported file, or pasted text."
                ),
                RadixNavigationGuideAction(
                    icon: "character.book.closed",
                    title: "Inspect what you find",
                    detail: "Tap a character for pronunciation, meaning, stroke animation, components, related characters, and phrases."
                ),
                RadixNavigationGuideAction(
                    icon: "highlighter",
                    title: "Follow phrases on a page",
                    detail: "Choose a phrase to highlight every matching character in its original page context."
                )
            ]
        case .study:
            return [
                RadixNavigationGuideAction(
                    icon: "star",
                    title: "Review what you saved",
                    detail: "Revisit favorite and recent characters, phrases, and pages without searching again."
                ),
                RadixNavigationGuideAction(
                    icon: "checkmark.circle",
                    title: "Classify added phrases",
                    detail: "Mark new phrases as accepted, checked, hidden, or rejected so your phrase collection stays useful."
                ),
                RadixNavigationGuideAction(
                    icon: "note.text",
                    title: "Find your own changes",
                    detail: "See added characters, edited meanings, notes, and other personal learning material."
                ),
                RadixNavigationGuideAction(
                    icon: "clock.arrow.circlepath",
                    title: "Use study snapshots",
                    detail: "Save a learning state before major changes, then add missing items back or replace the current state later."
                )
            ]
        case .aiLink:
            return [
                RadixNavigationGuideAction(
                    icon: "textformat.characters",
                    title: "Choose the subject",
                    detail: "Work with a character, phrase, search result, or complete saved page."
                ),
                RadixNavigationGuideAction(
                    icon: "list.bullet.clipboard",
                    title: "Choose what AI should do",
                    detail: "Translate, explain, create examples, compare ideas, or extract useful phrases."
                ),
                RadixNavigationGuideAction(
                    icon: "slider.horizontal.3",
                    title: "Reuse or customize instructions",
                    detail: "Turn tasks on and off, then edit the prompt when you need a different result."
                ),
                RadixNavigationGuideAction(
                    icon: "arrow.up.forward.app",
                    title: "Send it to your AI service",
                    detail: "Copy the prepared instruction or open ChatGPT, Gemini, Claude, DeepSeek, or your custom service."
                )
            ]
        case .myData:
            return [
                RadixNavigationGuideAction(
                    icon: "square.and.arrow.up",
                    title: "Save a full backup",
                    detail: "Choose a location for a portable copy of your additions, favorites, pages, notes, settings, and classifications."
                ),
                RadixNavigationGuideAction(
                    icon: "arrow.down.doc",
                    title: "Merge a backup",
                    detail: "Bring missing material onto this device while keeping newer work already here."
                ),
                RadixNavigationGuideAction(
                    icon: "arrow.clockwise",
                    title: "Replace this device",
                    detail: "Restore a backup as the device’s current Radix data when you want an exact replacement."
                ),
                RadixNavigationGuideAction(
                    icon: "shippingbox",
                    title: "Use advanced exports",
                    detail: "Advanced Pro can work with separate app and data files for inspection, transfer, or development."
                )
            ]
        case .settings:
            return [
                RadixNavigationGuideAction(
                    icon: "speaker.wave.2",
                    title: "Control read-aloud",
                    detail: "Turn Chinese speech on or off for character and phrase interactions."
                ),
                RadixNavigationGuideAction(
                    icon: "wand.and.stars",
                    title: "Choose your AI service",
                    detail: "Select where AI Link opens and optionally save private API keys for direct features."
                ),
                RadixNavigationGuideAction(
                    icon: "rectangle.3.group",
                    title: "Choose navigation appearance",
                    detail: "Keep Icons & Labels visible, or switch to Icons Only when the destinations are familiar."
                ),
                RadixNavigationGuideAction(
                    icon: "questionmark.circle",
                    title: "Get help again",
                    detail: "Open the glossary, replay the welcome screen, or reset these navigation tips."
                )
            ]
        }
    }

    var reminder: String {
        "Long-press a navigation button whenever you want to see this guide again."
    }
}

struct RadixNavigationGuideAction {
    let icon: String
    let title: String
    let detail: String
}
