import Foundation

enum RadixBrowsePreferences {
    private static let hasShownInteractionHintKey = "hasShownBrowseInteractionHintRowV1"
    private static let imageScriptModeKey = "browseImageScriptMode"
    private static let pageSortOrderKey = "browsePageSortOrder"
    private static let preferences = RadixPreferences.standard

    static var hasShownInteractionHint: Bool {
        get { preferences.bool(forKey: hasShownInteractionHintKey) }
        set { preferences.set(newValue, forKey: hasShownInteractionHintKey) }
    }

    static var imageScriptMode: String {
        get { preferences.string(forKey: imageScriptModeKey) ?? "simplified" }
        set { preferences.set(newValue, forKey: imageScriptModeKey) }
    }

    static var pageSortOrder: PageCollectionSortOrder {
        get {
            guard let rawValue = preferences.string(forKey: pageSortOrderKey) else {
                return .lastViewed
            }
            return PageCollectionSortOrder(rawValue: rawValue) ?? .lastViewed
        }
        set { preferences.set(newValue.rawValue, forKey: pageSortOrderKey) }
    }

    static var pageGridFilter: BrowsePageGridFilter {
        get {
            guard let rawValue = preferences.string(forKey: RadixPreferenceKey.browsePageGridFilter) else {
                return .all
            }
            return BrowsePageGridFilter(rawValue: rawValue) ?? .all
        }
        set { preferences.set(newValue.rawValue, forKey: RadixPreferenceKey.browsePageGridFilter) }
    }
}
