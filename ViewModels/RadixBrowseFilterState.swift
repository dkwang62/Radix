import Foundation

/// Browse-grid and component-explorer filter selections.
struct RadixBrowseFilterState {
    var favoritesOnly = false
    var minimumStroke = 0
    var maximumStroke = 30
    var radical = "none"
    var structure = "none"
    var rootMinimumStroke = 0
    var rootMaximumStroke = 30
    var rootRadical = "none"
    var rootStructure = "none"
    var gridSortMode: GridSortMode = .characterFrequency
    var gridScriptFilter: ScriptFilter = .any
}
