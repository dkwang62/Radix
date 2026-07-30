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
                "ConversationPracticeModels.swift",
                "PhraseModels.swift",
                "PinyinSearchNormalizer.swift",
                "PromptConfigRendering.swift",
                "PromptModels.swift",
                "RadixDataCompatibilityModels.swift",
                "RadixNavigationModels.swift",
                "RadixPreferenceKey.swift",
                "RadixPreferenceStore.swift",
                "SavedPageRules.swift",
                "UnifiedPackage.swift",
                "UserProfile.swift"
            ]
        ),
        .testTarget(
            name: "RadixCoreTests",
            dependencies: ["RadixCore"],
            path: "Tests/RadixCoreTests"
        )
    ]
)
