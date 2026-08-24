import Foundation
import Testing

@Suite("SwiftUI crash guardrails")
struct SwiftUICrashGuardrailTests {
    @Test("Smart Search examples remain fixed explicit children")
    func smartSearchExamplesAvoidDynamicForEach() throws {
        let source = try sourceText(at: "App/SmartSearchExamples.swift")

        #expect(!source.contains("ForEach("))
        #expect(source.components(separatedBy: "searchExampleButton(label:").count - 1 == 7)
    }

    @Test("Phrase animation chips avoid nested scroll readers")
    func phraseAnimationAvoidsScrollViewReader() throws {
        let source = try sourceText(at: "Views/PhraseInfoAnimation.swift")

        #expect(!source.contains("ScrollViewReader"))
        #expect(source.contains("ScrollView(.horizontal, showsIndicators: false)"))
    }

    @Test("Scene changes do not invalidate the full root navigation tree")
    func rootSceneLifecycleUsesIsolatedObserver() throws {
        let source = try sourceText(at: "App/RootView.swift")
        let rootViewSource = source.components(separatedBy: "private struct RadixSceneLifecycleObserver").first ?? source

        #expect(!rootViewSource.contains("@Environment(\\.scenePhase)"))
        #expect(rootViewSource.contains("RadixSceneLifecycleObserver("))
        #expect(source.contains("private struct RadixSceneLifecycleObserver"))
        #expect(source.components(separatedBy: "@Environment(\\.scenePhase)").count - 1 == 1)
    }

    private func sourceText(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repositoryURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryURL.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
