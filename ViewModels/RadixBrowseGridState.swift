import Foundation

/// Derived output and paging state for the Browse character grid.
struct RadixBrowseGridState {
    var filteredAllCount = 0
    var filteredComponentCount = 0
    var page = 0
    var items: [ComponentItem] = []
    var readingOrderCharacters: [String] = []
}

extension RadixStore {
    var gridFilteredAllCount: Int {
        get { browseGridState.filteredAllCount }
        set { browseGridState.filteredAllCount = newValue }
    }

    var gridFilteredComponentCount: Int {
        get { browseGridState.filteredComponentCount }
        set { browseGridState.filteredComponentCount = newValue }
    }

    var gridPage: Int {
        get { browseGridState.page }
        set { browseGridState.page = newValue }
    }

    var allGridItems: [ComponentItem] {
        get { browseGridState.items }
        set { browseGridState.items = newValue }
    }

    var allReadingOrderCharacters: [String] {
        get { browseGridState.readingOrderCharacters }
        set { browseGridState.readingOrderCharacters = newValue }
    }
}
