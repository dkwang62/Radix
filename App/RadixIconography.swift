import SwiftUI

/// Canonical customer-facing vocabulary. Keeping these terms in one place
/// prevents iPhone, iPad, and Mac labels from drifting apart.
enum RadixCopy {
    static let camera = String(localized: "Camera")
    static let browse = String(localized: "Browse")
    static let search = String(localized: "Search")
    static let study = String(localized: "Study")
    static let aiLink = String(localized: "AI Link")
    static let myData = String(localized: "My Data")
    static let settings = String(localized: "Settings")

    static let browsePurpose = String(localized: "Inspect the dictionary and create captured pages.")
    static let studyPurpose = String(localized: "Review what you decided to keep.")
    static let aiPurpose = String(localized: "Understand or transform material.")
    static let myDataPurpose = String(localized: "Protect, transfer, or export your work.")

    static let savedPage = String(localized: "Saved Page")
    static let savedPages = String(localized: "Saved Pages")
    static let pages = String(localized: "Pages")
    static let checkpoints = String(localized: "Checkpoints")
    static let createCheckpoint = String(localized: "Create Checkpoint")
    static let returnToCheckpoint = String(localized: "Return to Checkpoint")
    static let safetyCopy = String(localized: "Safety Copy")
    static let safetyCopies = String(localized: "Safety Copies")

    static let createBackup = String(localized: "Create Backup")
    static let mergeBackup = String(localized: "Merge Backup")
    static let restoreBackup = String(localized: "Restore Backup")
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

enum RadixTerm {
    static let backup = "Backup"
    static let history = "History"
    static let notes = "Notes"
    static let recent = "Recent"
    static let savedPage = "Saved Page"
    static let translation = "Page Explanation"
}

enum RadixGlossaryIcon {
    static let backup = "externaldrive"
    static let history = "clock"
    static let notes = "note.text"
    static let recent = "clock.badge"
    static let savedPage = "photo.on.rectangle"
    static let translation = "translate"
    static let fallback = "book.closed"

    static func systemImage(for term: String) -> String {
        switch term {
        case "Accepted": return "checkmark.circle"
        case "Added": return "plus.circle"
        case "Added Phrase": return "plus.bubble"
        case "AI Link": return RadixIcon.aiLink
        case "AI Prompt": return "text.badge.sparkles"
        case "API Key": return "key"
        case "Artifact", "Page Artifact": return "square.grid.2x2"
        case "Automatic AI Key": return "key.fill"
        case RadixTerm.backup: return backup
        case "Character": return "character"
        case "Checkpoint": return "clock.arrow.circlepath"
        case "Classify & Prune": return "slider.horizontal.3"
        case "Components": return "square.stack.3d.up"
        case "Conversation Practice": return "bubble.left.and.bubble.right"
        case "Create Conversation", "Create Theme Practice", "Create Practice from Page": return "sparkles"
        case "Data Portability": return "arrow.triangle.2.circlepath"
        case "Definition": return "text.book.closed"
        case "Meaning": return "text.alignleft"
        case "Extract Phrases": return "text.badge.plus"
        case "Sentence Practice", "Create Sentences", "Extract Page Sentences", "Extract Sentences": return "text.quote"
        case "Favorite": return RadixIcon.saved
        case "Favorite Sentence": return "star.circle"
        case "Gemini API", "Automatic AI", "Run Automatically": return "sparkles.rectangle.stack"
        case "Hidden": return "eye.slash"
        case RadixTerm.history: return history
        case "Make AI Text Page": return "doc.badge.plus"
        case "Manual AI Link", "Copy to AI Chat": return "arrow.up.forward.app"
        case "Memory": return "archivebox"
        case RadixTerm.notes: return notes
        case "Origin": return "sparkle.magnifyingglass"
        case "Page AI Task": return "wand.and.stars.inverse"
        case "Page Phrases": return "text.viewfinder"
        case "Phrase": return "text.bubble"
        case "Practice Pack": return "shippingbox"
        case "Quiz": return "questionmark.circle"
        case "Radical": return "leaf"
        case "Radix Plus": return "crown"
        case RadixTerm.recent: return recent
        case "Rejected": return "xmark.circle"
        case RadixTerm.savedPage: return savedPage
        case "Sentence": return "quote.bubble"
        case "Sentence Database", "Saved Sentences", "Sentence Example": return "tray.full"
        case "Sentence Phrases": return "text.bubble.fill"
        case "Simplified": return "character.book.closed"
        case "Stroke Order": return "scribble"
        case "Structure": return "rectangle.split.3x1"
        case "Study": return RadixIcon.study
        case "Tier": return "chart.bar"
        case "Traditional": return "character.book.closed.zh"
        case RadixTerm.translation: return translation
        case "Unreviewed": return "questionmark.circle"
        default: return fallback
        }
    }
}

struct RadixTermLabel: View {
    let title: String
    let term: String

    init(_ title: String? = nil, term: String) {
        self.title = title ?? term
        self.term = term
    }

    var body: some View {
        Label(title, systemImage: RadixGlossaryIcon.systemImage(for: term))
    }
}

struct RadixHelpLabel: View {
    var body: some View {
        Label("Help", systemImage: RadixIcon.help)
    }
}

enum RadixNavigationItem: Int, CaseIterable, Identifiable {
    case scan = 0
    case browse = 2
    case search = 1
    case pages = 7
    case study = 3
    case aiLink = 4
    case myData = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .scan: return RadixCopy.camera
        case .browse: return RadixCopy.browse
        case .search: return RadixCopy.search
        case .pages: return RadixCopy.pages
        case .study: return RadixCopy.study
        case .aiLink: return RadixCopy.aiLink
        case .myData: return RadixCopy.myData
        }
    }

    var compactTitle: String {
        switch self {
        case .scan: return "Camera"
        case .aiLink: return "AI"
        case .pages: return RadixCopy.pages
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
        case .pages:
            return "Work with captured pages and everything created from them."
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
        case .pages: return RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage)
        case .study: return RadixIcon.study
        case .aiLink: return RadixIcon.aiLink
        case .myData: return RadixIcon.myData
        }
    }

    var guideTopic: RadixNavigationGuideTopic? {
        switch self {
        case .browse: return .browse
        case .pages: return .pages
        case .study: return .study
        case .aiLink: return .aiLink
        case .myData: return .myData
        case .scan, .search: return nil
        }
    }
}

enum RadixNavigationGuideTopic: String, CaseIterable, Identifiable {
    case browse
    case pages
    case study
    case aiLink
    case myData
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse: return RadixCopy.browse
        case .pages: return RadixCopy.pages
        case .study: return RadixCopy.study
        case .aiLink: return RadixCopy.aiLink
        case .myData: return RadixCopy.myData
        case .settings: return RadixCopy.settings
        }
    }

    var icon: String {
        switch self {
        case .browse: return RadixIcon.browse
        case .pages: return RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage)
        case .study: return RadixIcon.study
        case .aiLink: return RadixIcon.aiLink
        case .myData: return RadixIcon.myData
        case .settings: return RadixIcon.settings
        }
    }

    var summary: String {
        switch self {
        case .browse:
            return "\(RadixCopy.browsePurpose) Browse connects dictionary detail with source context, so you can move from a character to its structure, phrases, and real usage."
        case .pages:
            return "Pages keeps captured Chinese and its generated artifacts together, so translation, phrases, sentences, practice, quiz, and deletion stay attached to the source."
        case .study:
            return "\(RadixCopy.studyPurpose) Study focuses on the material you decided to keep: sentences, Conversation practice, favorites, recent items, added phrases, and checkpoints."
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
                    title: "Create saved pages",
                    detail: "Turn a photo, imported file, or pasted text into a page, then continue in Pages."
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
        case .pages:
            return [
                RadixNavigationGuideAction(
                    icon: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage),
                    title: "Start from the source",
                    detail: "Open a captured page once, then manage its generated work from the same row."
                ),
                RadixNavigationGuideAction(
                    icon: "square.grid.2x2",
                    title: "Keep artifacts attached",
                    detail: "Page Explanation, page phrases, corrected OCR, Sentences, Conversation, and Quiz actions remain attached to the saved page that produced them."
                ),
                RadixNavigationGuideAction(
                    icon: "book.pages",
                    title: "Inspect source when needed",
                    detail: "Use Source only when you want original OCR or page-context inspection; normal learning work stays in Pages."
                ),
                RadixNavigationGuideAction(
                    icon: "trash",
                    title: "Delete with context",
                    detail: "Page deletion belongs beside the page and should explain which page-owned artifacts will also be removed."
                )
            ]
        case .study:
            return [
                RadixNavigationGuideAction(
                    icon: RadixGlossaryIcon.systemImage(for: "Practice Pack"),
                    title: "Practice",
                    detail: "Open page-derived Sentences or Conversation practice from Study, then return to the page that started it."
                ),
                RadixNavigationGuideAction(
                    icon: RadixGlossaryIcon.systemImage(for: "Favorite"),
                    title: "Memory",
                    detail: "Favorites, added phrases, favorite sentences, and progress stay as learning memory even when a page-owned artifact is removed."
                ),
                RadixNavigationGuideAction(
                    icon: "clock.arrow.circlepath",
                    title: "Checkpoints",
                    detail: "Save the current state as a memory checkpoint before large study sessions or cleanup."
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
                    title: "Set up AI",
                    detail: "Choose where AI Link opens, configure automatic AI, or save manual AI keys."
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
        "Open Help from the screen title menu whenever you want to see this guide again."
    }
}

struct RadixNavigationGuideAction {
    let icon: String
    let title: String
    let detail: String
}
