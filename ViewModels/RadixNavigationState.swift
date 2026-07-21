import Foundation

enum StudyNavigationTarget: String, CaseIterable, Identifiable, Equatable {
    case recent
    case favorites
    case savedPages
    case addedPhrases
    case conversationPractice
    case sentences
    case checkpoints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .savedPages: return "Saved Pages"
        case .addedPhrases: return "Added Phrases"
        case .conversationPractice: return "Conversation Practices"
        case .sentences: return "Sentences"
        case .checkpoints: return "Checkpoints"
        }
    }
}

/// The lightweight, platform-independent state that describes where the user is
/// in the app. `RadixStore` continues to expose compatibility properties so views
/// do not need to know how navigation state is stored.
struct RadixNavigationState: Equatable {
    var route: AppRoute = .search
    var homeTab: HomeTab = .filter
    var sidebarNavigationStyle: SidebarNavigationStyle = .defaultStyle
    var rootsReturnContext: RootsReturnContext?
    var shouldRevealAPIKeys = false
    var pendingConversationPracticeTopicID: String?
    var activeStudySectionTitle = "Saved Pages"
    var requestedStudyNavigationTarget: StudyNavigationTarget?
    var previewCharacter: String?
    var history: [String] = []
}

extension RadixStore {
    var route: AppRoute {
        get { navigationState.route }
        set { navigationState.route = newValue }
    }

    var homeTab: HomeTab {
        get { navigationState.homeTab }
        set { navigationState.homeTab = newValue }
    }

    var sidebarNavigationStyle: SidebarNavigationStyle {
        get { navigationState.sidebarNavigationStyle }
        set {
            navigationState.sidebarNavigationStyle = newValue
            preferences.set(newValue.rawValue, forKey: RadixPreferenceKey.sidebarNavigationStyle)
        }
    }

    var rootsReturnContext: RootsReturnContext? {
        get { navigationState.rootsReturnContext }
        set { navigationState.rootsReturnContext = newValue }
    }

    var shouldRevealAPIKeys: Bool {
        get { navigationState.shouldRevealAPIKeys }
        set { navigationState.shouldRevealAPIKeys = newValue }
    }

    var pendingConversationPracticeTopicID: String? {
        get { navigationState.pendingConversationPracticeTopicID }
        set { navigationState.pendingConversationPracticeTopicID = newValue }
    }

    var activeStudySectionTitle: String {
        get { navigationState.activeStudySectionTitle }
        set { navigationState.activeStudySectionTitle = newValue }
    }

    var requestedStudyNavigationTarget: StudyNavigationTarget? {
        get { navigationState.requestedStudyNavigationTarget }
        set { navigationState.requestedStudyNavigationTarget = newValue }
    }

    var previewCharacter: String? {
        get { navigationState.previewCharacter }
        set {
            navigationState.previewCharacter = newValue
            rememberLastPreviewedCharacter(newValue)
        }
    }

    var history: [String] {
        get { navigationState.history }
        set { navigationState.history = newValue }
    }
}
