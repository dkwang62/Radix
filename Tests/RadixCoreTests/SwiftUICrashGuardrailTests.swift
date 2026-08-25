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

    @Test("Study root delegates section state and navigation transitions")
    func studyRootUsesSectionStateCoordinator() throws {
        let rootSource = try sourceText(at: "App/FavouritesTab.swift")
        let stateSource = try sourceText(at: "App/FavouritesStudyScreenState.swift")
        let lifecycleSource = try sourceText(at: "App/FavouritesTabLifecycle.swift")

        #expect(rootSource.components(separatedBy: "@State var").count - 1 == 1)
        #expect(rootSource.contains("@State var screenState = StudyScreenState()"))
        #expect(stateSource.contains("struct StudyNavigationScreenState"))
        #expect(stateSource.contains("struct StudySentenceScreenState"))
        #expect(stateSource.contains("struct StudyConversationPracticeScreenState"))
        #expect(stateSource.contains("struct StudyPageScreenState"))
        #expect(stateSource.contains("mutating func presentReview("))
        #expect(stateSource.contains("mutating func returnToOriginatingPage()"))
        #expect(lifecycleSource.contains("screenState.presentReview(scope: .all)"))
        #expect(lifecycleSource.contains("screenState.presentCheckpoints()"))
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
