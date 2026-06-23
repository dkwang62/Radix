import Foundation

/// User-facing search session state. Search execution and repository-backed
/// results remain coordinated by `RadixStore`.
struct RadixSearchState: Equatable {
    var query = ""
    var mode: SearchMode = .smart
    var scriptFilter: ScriptFilter = .any
    var hasPerformedSearch = false
    var lastQuery = ""
    var history: [String] = []
}
