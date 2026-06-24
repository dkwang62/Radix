import Foundation

/// The lightweight, platform-independent state that describes where the user is
/// in the app. `RadixStore` continues to expose compatibility properties so views
/// do not need to know how navigation state is stored.
struct RadixNavigationState: Equatable {
    var route: AppRoute = .search
    var homeTab: HomeTab = .filter
    var sidebarNavigationStyle: SidebarNavigationStyle = .descriptive
    var rootsReturnContext: RootsReturnContext?
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
