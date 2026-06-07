import Foundation

enum RadixInteractionPreferences {
    private static let hasAnimatedHintRowKey = "hasAnimatedInteractionHintRowV2"
    private static let preferences = RadixPreferences.standard

    static var hasAnimatedHintRow: Bool {
        get { preferences.bool(forKey: hasAnimatedHintRowKey) }
        set { preferences.set(newValue, forKey: hasAnimatedHintRowKey) }
    }
}
