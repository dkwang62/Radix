import Foundation

enum RadixPhrasePreferences {
    private static let animationScriptKey = "phraseInfoAnimationScript"
    private static let preferences = RadixPreferences.standard

    static var animationScript: String {
        get { preferences.string(forKey: animationScriptKey) ?? "simplified" }
        set { preferences.set(newValue, forKey: animationScriptKey) }
    }
}
