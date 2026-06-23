import Foundation

/// Derived output and paging state for the Browse character grid.
struct RadixBrowseGridState {
    var filteredAllCount = 0
    var filteredComponentCount = 0
    var page = 0
    var items: [ComponentItem] = []
    var readingOrderCharacters: [String] = []
}
