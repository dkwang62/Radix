import Foundation
import Testing
@testable import RadixCore

@Suite("Cross-platform data choices")
struct DataChoiceCompatibilityTests {
    @Test("Script-filter identifiers remain profile compatible")
    func scriptFilterIdentifiers() {
        #expect(ScriptFilter.any.rawValue == "Any")
        #expect(ScriptFilter.simplified.rawValue == "Simplified")
        #expect(ScriptFilter.traditional.rawValue == "Traditional")
        #expect(ScriptFilter(rawValue: "Simplified") == .simplified)
    }

    @Test("Restore modes expose stable cross-platform identifiers")
    func restoreModeIdentifiers() throws {
        #expect(RestoreMode.additive.rawValue == "additive")
        #expect(RestoreMode.complete.rawValue == "complete")

        let encoded = try JSONEncoder().encode(RestoreMode.complete)
        #expect(try JSONDecoder().decode(RestoreMode.self, from: encoded) == .complete)
    }

    @Test("Bundled standard data never imports authoring pages")
    func bundledStandardDataExcludesSavedPages() {
        let pageID = UUID()
        let payload = PortableBackupPayload.unified(UnifiedPackage(
            schemaVersion: PortableBackupCodec.currentSchemaVersion,
            phrases: [],
            profile: UserProfile(schemaVersion: 1, favouritesList: []),
            collections: [CharacterCollection(
                id: pageID,
                name: "Bundled sample",
                characters: ["学"],
                createdAt: .now,
                sourceType: .imported,
                isFavorite: false
            )],
            selectedAICollectionID: pageID
        ))

        guard case .unified(let sanitized) = BundledStandardDataRules.sanitizedPayload(payload) else {
            Issue.record("Expected unified standard data payload")
            return
        }

        #expect(sanitized.collections == nil)
        #expect(sanitized.selectedAICollectionID == nil)
    }
}
