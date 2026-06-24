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
}
