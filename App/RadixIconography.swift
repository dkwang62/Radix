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

    static let browsePurpose = String(localized: "Inspect the dictionary or captured pages.")
    static let studyPurpose = String(localized: "Review what you decided to keep.")
    static let aiPurpose = String(localized: "Understand or transform material.")
    static let myDataPurpose = String(localized: "Protect, transfer, or export your work.")

    static let savedPage = String(localized: "Saved Page")
    static let savedPages = String(localized: "Saved Pages")
    static let createCheckpoint = String(localized: "Create Checkpoint")
    static let returnToCheckpoint = String(localized: "Return to Checkpoint")

    static let createBackup = String(localized: "Create Backup")
    static let mergeBackup = String(localized: "Merge Backup")
    static let replaceFromBackup = String(localized: "Replace from Backup")
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
            return "Find characters and phrases by Chinese, pinyin, or English meaning."
        case .browse:
            return RadixCopy.browsePurpose
        case .study:
            return RadixCopy.studyPurpose
        case .aiLink:
            return RadixCopy.aiPurpose
        case .myData:
            return RadixCopy.myDataPurpose
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
            return "\(RadixCopy.browsePurpose) Browse connects dictionary detail with the original page, so you can move from a character to its structure, phrases, and real context."
        case .study:
            return "\(RadixCopy.studyPurpose) Study brings your favorites, recent work, additions, notes, and saved learning states together for deliberate review."
        case .aiLink:
            return "\(RadixCopy.aiPurpose) AI Link goes beyond fixed dictionary definitions with contextual translation, deeper explanation, phrase extraction, and newer language."
        case .myData:
            return "\(RadixCopy.myDataPurpose) My Data provides backups, restore options, portable exports, and code or data foundations for building further with AI agents."
        case .settings:
            return "Settings adapts Radix to the way you learn and work. It controls speech, navigation guidance, AI connections, privacy-sensitive keys, and access to help."
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
                    title: "Go beyond a short definition",
                    detail: "Ask for nuance, background, usage, comparisons, examples, and concepts that a compact dictionary entry cannot fully explain."
                ),
                RadixNavigationGuideAction(
                    icon: "quote.bubble",
                    title: "Understand meaning in context",
                    detail: "Translate a phrase or complete saved page according to how the words are being used, rather than translating each character in isolation."
                ),
                RadixNavigationGuideAction(
                    icon: "text.badge.plus",
                    title: "Discover newer language",
                    detail: "Explore current phrases, names, slang, technical ideas, and changing concepts that may not yet appear in traditional dictionaries."
                ),
                RadixNavigationGuideAction(
                    icon: "list.bullet.clipboard",
                    title: "Extract phrases worth keeping",
                    detail: "Find meaningful expressions in a saved page, review the results, and add useful phrases back into Radix for later study."
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
                    detail: "Export source, JSON, and databases as a foundation for AI coding agents to help you author, adapt, or build your own software."
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
        "Select the same navigation button twice in a row whenever you want to see this guide again."
    }
}

struct RadixNavigationGuideAction {
    let icon: String
    let title: String
    let detail: String
}
