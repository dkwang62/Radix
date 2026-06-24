import Testing
@testable import RadixCore

@Suite("Navigation compatibility")
struct NavigationCompatibilityTests {
    @Test("Persisted route and tab identifiers remain stable")
    func stableRouteIdentifiers() {
        #expect(AppRoute.search.rawValue == "Search")
        #expect(AppRoute.capture.rawValue == "Capture")
        #expect(AppRoute.aiLink.rawValue == "AI Link")
        #expect(AppRoute.favourites.rawValue == "Favourites")
        #expect(AppRoute.settings.rawValue == "Settings")
        #expect(HomeTab.smart.rawValue == "Smart Search")
        #expect(HomeTab.filter.rawValue == "Filter")
        #expect(HomeTab.dataEdit.rawValue == "DataEdit")
    }

    @Test("Legacy sidebar style still migrates")
    func legacySidebarStyle() {
        #expect(SidebarNavigationStyle.fromStoredValue("Full") == .descriptive)
        #expect(SidebarNavigationStyle.fromStoredValue("Compact") == .compact)
        #expect(SidebarNavigationStyle.fromStoredValue("Unknown") == nil)
    }

    @Test("Tab indices keep their established layout mapping")
    func stableTabIndices() {
        #expect(HomeTab.smart.index == 0)
        #expect(HomeTab.filter.index == 1)
        #expect(HomeTab.favourites.index == 3)
        #expect(HomeTab.dataEdit.index == 5)
    }
}
