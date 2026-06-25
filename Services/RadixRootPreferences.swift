import Foundation

enum RadixRootPreferences {
    private static let hasSeenWelcomeKey = "hasSeenRadixWelcomeV1"
    private static let hasUsedSidebarNavigationKey = "hasUsedSidebarNavigationV1"
    private static let preferences = RadixPreferences.standard
    private static let navigationGuidePrefix = "hasSeenNavigationGuideV1."
    private static let hasSeenPageAIOrientationKey = "hasSeenPageAIOrientationV1"

    static var hasSeenWelcome: Bool {
        get { preferences.bool(forKey: hasSeenWelcomeKey) }
        set { preferences.set(newValue, forKey: hasSeenWelcomeKey) }
    }

    static var hasUsedSidebarNavigation: Bool {
        get { preferences.bool(forKey: hasUsedSidebarNavigationKey) }
        set { preferences.set(newValue, forKey: hasUsedSidebarNavigationKey) }
    }

    static func hasSeenNavigationGuide(_ id: String) -> Bool {
        preferences.bool(forKey: navigationGuidePrefix + id)
    }

    static func setNavigationGuideSeen(_ id: String) {
        preferences.set(true, forKey: navigationGuidePrefix + id)
    }

    static func resetNavigationGuides() {
        ["browse", "study", "aiLink", "myData", "settings"].forEach {
            preferences.removeObject(forKey: navigationGuidePrefix + $0)
        }
    }

    static var hasSeenPageAIOrientation: Bool {
        get { preferences.bool(forKey: hasSeenPageAIOrientationKey) }
        set { preferences.set(newValue, forKey: hasSeenPageAIOrientationKey) }
    }
}
