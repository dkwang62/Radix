import Foundation
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

    @Test("Capture completion auto-opens only for its active Capture context")
    func captureCompletionNavigationOwnership() {
        let operationID = UUID()

        #expect(CaptureCompletionNavigationPolicy.shouldAutoOpen(
            operationID: operationID,
            activeOperationID: operationID,
            captureContextIsActive: true,
            currentRoute: .capture
        ))
        #expect(!CaptureCompletionNavigationPolicy.shouldAutoOpen(
            operationID: operationID,
            activeOperationID: UUID(),
            captureContextIsActive: true,
            currentRoute: .capture
        ))
        #expect(!CaptureCompletionNavigationPolicy.shouldAutoOpen(
            operationID: operationID,
            activeOperationID: operationID,
            captureContextIsActive: false,
            currentRoute: .capture
        ))
        #expect(!CaptureCompletionNavigationPolicy.shouldAutoOpen(
            operationID: operationID,
            activeOperationID: operationID,
            captureContextIsActive: true,
            currentRoute: .aiLink
        ))
    }

    @Test("Legacy sidebar style still migrates")
    func legacySidebarStyle() {
        #expect(SidebarNavigationStyle.defaultStyle == .descriptive)
        #expect(SidebarNavigationStyle.fromStoredValue("Full") == .descriptive)
        #expect(SidebarNavigationStyle.fromStoredValue("Compact") == .compact)
        #expect(SidebarNavigationStyle.fromStoredValue("Unknown") == nil)
        #expect(SidebarNavigationStyle.descriptive.displayName == "Icons & Labels")
        #expect(SidebarNavigationStyle.compact.displayName == "Icons Only")
    }

    @Test("Tab indices keep their established layout mapping")
    func stableTabIndices() {
        #expect(HomeTab.smart.index == 0)
        #expect(HomeTab.filter.index == 1)
        #expect(HomeTab.favourites.index == 3)
        #expect(HomeTab.dataEdit.index == 5)
    }

    @Test("History strip appears only on exploratory surfaces")
    func historyStripDisplayPolicy() {
        #expect(HistoryStripDisplayPolicy.shouldShow(route: .search, homeTab: .smart, hasItems: true))
        #expect(HistoryStripDisplayPolicy.shouldShow(route: .search, homeTab: .filter, hasItems: true))
        #expect(HistoryStripDisplayPolicy.shouldShow(route: .search, homeTab: .favourites, hasItems: true))
        #expect(HistoryStripDisplayPolicy.shouldShow(route: .lineage, homeTab: .smart, hasItems: true))
        #expect(HistoryStripDisplayPolicy.shouldShow(route: .favourites, homeTab: .smart, hasItems: true))

        #expect(!HistoryStripDisplayPolicy.shouldShow(route: .favourites, homeTab: .smart, hasItems: false))
        #expect(HistoryStripDisplayPolicy.shouldShow(route: .favourites, homeTab: .smart, hasItems: false, hasCaptureButton: true))
        #expect(!HistoryStripDisplayPolicy.shouldShow(route: .settings, homeTab: .smart, hasItems: false, hasCaptureButton: true))
        #expect(!HistoryStripDisplayPolicy.shouldShow(route: .search, homeTab: .dataEdit, hasItems: true))
        #expect(!HistoryStripDisplayPolicy.shouldShow(route: .capture, homeTab: .smart, hasItems: true))
        #expect(!HistoryStripDisplayPolicy.shouldShow(route: .aiLink, homeTab: .smart, hasItems: true))
        #expect(!HistoryStripDisplayPolicy.shouldShow(route: .settings, homeTab: .smart, hasItems: true))
    }

    @Test("History strip renders a bounded prefix")
    func historyStripVisibleItemsAreCapped() {
        let items = (0..<120).map(String.init)
        let visible = HistoryStripDisplayPolicy.visibleItems(from: items)

        #expect(visible.count == HistoryStripDisplayPolicy.visibleItemLimit)
        #expect(visible.first == "0")
        #expect(visible.last == "79")
    }

    @Test("Clipboard History considers only the first eight Chinese characters")
    func clipboardHistoryCharacterWindow() {
        #expect(MemoryStripClipboardRules.chineseCharacters(in: "News: 中，国人民学习中文每天") == ["中", "国", "人", "民", "学", "习", "中", "文"])
        #expect(MemoryStripClipboardRules.chineseCharacters(in: "no Chinese here").isEmpty)
    }

    @Test("Clipboard History prioritizes longest phrases before uncovered characters")
    func clipboardHistoryPhrasePriority() {
        let items = MemoryStripClipboardRules.prioritizedItems(
            characters: ["中", "国", "人", "民"],
            knownPhrases: ["中国", "中国人", "人民"],
            supportsCharacter: { _ in true }
        )
        #expect(items == ["中国人", "民"])

        let paired = MemoryStripClipboardRules.prioritizedItems(
            characters: ["中", "国", "人", "民"],
            knownPhrases: ["中国", "人民"],
            supportsCharacter: { _ in true }
        )
        #expect(paired == ["中国", "人民"])
    }

    @Test("Clipboard History falls back to supported unique characters")
    func clipboardHistoryCharacterFallback() {
        let items = MemoryStripClipboardRules.prioritizedItems(
            characters: ["我", "爱", "我", "们"],
            knownPhrases: [],
            supportsCharacter: { $0 != "们" }
        )
        #expect(items == ["我", "爱"])
    }

    @Test("Search history keeps only the latest unique queries")
    func searchHistoryIsBoundedAndDeduplicated() {
        let values = (0..<SearchHistoryRules.retainedQueryLimit + 5).map { "query-\($0)" }
        let bounded = SearchHistoryRules.normalized(values)
        #expect(bounded.count == SearchHistoryRules.retainedQueryLimit)
        #expect(bounded.first == "query-5")
        #expect(bounded.last == "query-44")

        let repeated = SearchHistoryRules.appending(" query-20 ", to: bounded)
        #expect(repeated.count == SearchHistoryRules.retainedQueryLimit)
        #expect(repeated.last == "query-20")
        #expect(repeated.filter { $0 == "query-20" }.count == 1)
    }

    @Test("Browse page and Study Pages use explicit buttons instead of return bars")
    func browseStudyPagePairSuppressesCrossTabReturn() {
        let browsePageOrigin = CrossTabReturnVisibilityContext(
            route: .search,
            homeTab: .filter,
            isStudyPages: false,
            hasSelectedBrowsePage: true
        )
        let studyPagesOrigin = CrossTabReturnVisibilityContext(
            route: .favourites,
            homeTab: nil,
            isStudyPages: true,
            hasSelectedBrowsePage: false
        )

        #expect(!CrossTabReturnVisibilityPolicy.shouldShow(
            current: CrossTabReturnVisibilityContext(
                route: .favourites,
                homeTab: nil,
                isStudyPages: true,
                hasSelectedBrowsePage: true
            ),
            origin: browsePageOrigin
        ))
        #expect(!CrossTabReturnVisibilityPolicy.shouldShow(
            current: CrossTabReturnVisibilityContext(
                route: .search,
                homeTab: .filter,
                isStudyPages: false,
                hasSelectedBrowsePage: true
            ),
            origin: studyPagesOrigin
        ))
    }

    @Test("Cross-tab return remains available outside Browse page Study Pages pair")
    func ordinaryCrossTabReturnStillShows() {
        let searchOrigin = CrossTabReturnVisibilityContext(
            route: .search,
            homeTab: .smart,
            isStudyPages: false,
            hasSelectedBrowsePage: false
        )

        #expect(CrossTabReturnVisibilityPolicy.shouldShow(
            current: CrossTabReturnVisibilityContext(
                route: .settings,
                homeTab: nil,
                isStudyPages: false,
                hasSelectedBrowsePage: false
            ),
            origin: searchOrigin
        ))
        #expect(!CrossTabReturnVisibilityPolicy.shouldShow(
            current: CrossTabReturnVisibilityContext(
                route: .lineage,
                homeTab: nil,
                isStudyPages: false,
                hasSelectedBrowsePage: false
            ),
            origin: searchOrigin
        ))

        let studySentencesOrigin = CrossTabReturnVisibilityContext(
            route: .favourites,
            homeTab: nil,
            isStudyPages: false,
            hasSelectedBrowsePage: false
        )
        #expect(CrossTabReturnVisibilityPolicy.shouldShow(
            current: CrossTabReturnVisibilityContext(
                route: .search,
                homeTab: .filter,
                isStudyPages: false,
                hasSelectedBrowsePage: true
            ),
            origin: studySentencesOrigin
        ))
    }
}
