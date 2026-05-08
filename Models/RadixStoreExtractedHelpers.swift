import Foundation

struct GridPageSlice<Element> {
    let items: [Element]
    let page: Int
    let pageCount: Int
    let start: Int
    let end: Int
}

enum GridPaging {
    static func pageCount(totalCount: Int, pageSize: Int) -> Int {
        guard pageSize > 0 else { return 1 }
        return totalCount == 0 ? 1 : Int(ceil(Double(totalCount) / Double(pageSize)))
    }

    static func pageSlice<Element>(_ items: [Element], page: Int, pageSize: Int) -> GridPageSlice<Element> {
        guard pageSize > 0, !items.isEmpty else {
            return GridPageSlice(items: [], page: 0, pageCount: 1, start: 0, end: 0)
        }

        let count = pageCount(totalCount: items.count, pageSize: pageSize)
        let safePage = min(max(0, page), max(0, count - 1))
        let start = safePage * pageSize
        let end = min(start + pageSize, items.count)
        let slice = start < end ? Array(items[start..<end]) : []
        return GridPageSlice(items: slice, page: safePage, pageCount: count, start: start, end: end)
    }

    static func nextPage(current: Int, pageCount: Int) -> Int {
        min(current + 1, max(0, pageCount - 1))
    }

    static func previousPage(current: Int) -> Int {
        max(0, current - 1)
    }

    static func pageForIndex(_ index: Int, pageSize: Int) -> Int {
        guard pageSize > 0 else { return 0 }
        return max(0, index) / pageSize
    }
}

struct BrowseMemoryHighlightResult {
    let offsets: Set<Int>
    let firstOffset: Int?
}

enum BrowseMemoryHighlighter {
    static func matches(in characters: [String], item: String) -> BrowseMemoryHighlightResult {
        let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return BrowseMemoryHighlightResult(offsets: [], firstOffset: nil)
        }

        let offsets: Set<Int>
        if key.count == 1 {
            offsets = Set(characters.indices.filter { characters[$0] == key })
        } else {
            let phraseCharacters = key.map(String.init)
            offsets = phraseOffsets(in: characters, phraseCharacters: phraseCharacters)
        }

        return BrowseMemoryHighlightResult(offsets: offsets, firstOffset: offsets.min())
    }

    private static func phraseOffsets(in characters: [String], phraseCharacters: [String]) -> Set<Int> {
        guard !phraseCharacters.isEmpty, phraseCharacters.count <= characters.count else { return [] }

        var matchedOffsets = Set<Int>()
        let maxStart = characters.count - phraseCharacters.count
        for start in 0...maxStart {
            let end = start + phraseCharacters.count
            if Array(characters[start..<end]) == phraseCharacters {
                matchedOffsets.formUnion(start..<end)
            }
        }
        return matchedOffsets
    }
}

enum MemoryStripState {
    static func inserting(_ item: String, into items: [String]) -> ([String], Int) {
        let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return (items, min(0, max(0, items.count - 1))) }
        var next = items
        if let existing = next.firstIndex(of: key) {
            next.remove(at: existing)
        }
        next.insert(key, at: 0)
        return (next, 0)
    }

    static func removing(_ item: String, from items: [String], currentIndex: Int) -> ([String], Int) {
        let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
        var next = items
        guard let existing = next.firstIndex(of: key) else {
            return (items, items.isEmpty ? 0 : min(currentIndex, items.count - 1))
        }
        next.remove(at: existing)
        return (next, next.isEmpty ? 0 : min(currentIndex, next.count - 1))
    }

    static func stepping(in items: [String], currentIndex: Int, delta: Int) -> (index: Int, item: String)? {
        let nextIndex = currentIndex + delta
        guard items.indices.contains(nextIndex) else { return nil }
        return (nextIndex, items[nextIndex])
    }

    static func canGoBack(currentIndex: Int) -> Bool {
        currentIndex > 0
    }

    static func canGoForward(currentIndex: Int, count: Int) -> Bool {
        currentIndex + 1 < count
    }
}

enum FavoriteOrdering {
    static func sortedByAddedDate<T>(
        _ values: [T],
        dateForValue: (T) -> Date?,
        fallbackSort: (T, T) -> Bool
    ) -> [T] {
        values.sorted { lhs, rhs in
            let lhsDate = dateForValue(lhs)
            let rhsDate = dateForValue(rhs)
            switch (lhsDate, rhsDate) {
            case let (lhs?, rhs?):
                if lhs != rhs { return lhs > rhs }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }
            return fallbackSort(lhs, rhs)
        }
    }
}

enum PromptTaskSelection {
    static func normalized(_ selectedIDs: [String], availableIDs: [String], defaultIDs: [String]) -> [String] {
        let available = Set(availableIDs)
        let filtered = selectedIDs.filter { available.contains($0) }
        return filtered.isEmpty ? defaultIDs.filter { available.contains($0) } : filtered
    }

    static func toggled(_ taskID: String, in selectedIDs: [String], isEnabled: Bool) -> [String] {
        var next = selectedIDs
        if isEnabled {
            if !next.contains(taskID) {
                next.append(taskID)
            }
        } else {
            next.removeAll { $0 == taskID }
        }
        return next
    }
}
