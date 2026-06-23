import Foundation

/// Device-level AI provider preferences and credentials.
struct RadixAIProviderState {
    var defaultPreset: DefaultAIPreset = .chatGPT
    var customURLString = ""
    var openAIAPIKey = ""
    var geminiAPIKey = ""
    var claudeAPIKey = ""
    var deepSeekAPIKey = ""
    var customAIAPIKey = ""
    var geminiModelID = "gemini-2.5-flash-lite"
}
