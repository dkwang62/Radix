import Foundation

enum RadixRootPreferences {
    private static let hasSeenWelcomeKey = "hasSeenRadixWelcomeV1"
    private static let hasUsedSidebarNavigationKey = "hasUsedSidebarNavigationV1"
    private static let preferences = RadixPreferences.standard

    static var hasSeenWelcome: Bool {
        get { preferences.bool(forKey: hasSeenWelcomeKey) }
        set { preferences.set(newValue, forKey: hasSeenWelcomeKey) }
    }

    static var hasUsedSidebarNavigation: Bool {
        get { preferences.bool(forKey: hasUsedSidebarNavigationKey) }
        set { preferences.set(newValue, forKey: hasUsedSidebarNavigationKey) }
    }
}
