// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadixCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "RadixCore", targets: ["RadixCore"])
    ],
    targets: [
        .target(
            name: "RadixCore",
            path: "Models",
            exclude: [
                "BackupSummaryBuilder.swift",
                "BrowseGridLayout.swift",
                "ImagePhraseMatcher.swift",
                "RadixStoreExtractedHelpers.swift",
                "ResponsiveFont.swift"
            ],
            sources: [
                "ComponentModels.swift",
                "CaptureModels.swift",
                "ConversationPracticeLibraryModels.swift",
                "ConversationPracticeModels.swift",
                "ConversationPracticeProgressModels.swift",
                "ConversationPracticeQuizRules.swift",
                "ConversationPracticeTopicModels.swift",
                "ConversationPracticeValidationModels.swift",
                "FavoriteSentenceModels.swift",
                "RadixCaptureModels.swift",
                "SentenceLibraryStore.swift",
                "SentenceExampleModels.swift",
                "StudyPersistenceStores.swift",
                "PhraseModels.swift",
                "PinyinSearchNormalizer.swift",
                "OpenAICompatibleAIModels.swift",
                "PromptConfigRendering.swift",
                "PromptModels.swift",
                "PromptTemplateRevision.swift",
                "PromptTaskDefaults.swift",
                "RadixDataCompatibilityModels.swift",
                "RadixNavigationModels.swift",
                "RadixPreferenceKey.swift",
                "RadixPreferenceStore.swift",
                "SavedPageRules.swift",
                "PageDeletionJournal.swift",
                "RestoreRollbackJournal.swift",
                "UnifiedPackage.swift",
                "UserProfile.swift"
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "RadixCoreTests",
            dependencies: ["RadixCore"],
            path: "Tests/RadixCoreTests"
        )
    ]
)
