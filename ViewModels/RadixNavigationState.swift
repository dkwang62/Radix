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
