import Testing
@testable import RadixCore

@Suite("Browse grid computation")
struct BrowseGridComputationTests {
    @Test("Reading order retains duplicate count while rendering unique characters")
    func readingOrderPreservesSourceCount() {
        let one = item("一", strokes: 1, rank: 1, usage: 9)
        let two = item("二", strokes: 2, rank: 2, usage: 2)
        let metadata = [
            "一": BrowseGridItemMetadata(structure: "single", supportsSimplified: true, supportsTraditional: true, isComponent: true),
            "二": BrowseGridItemMetadata(structure: "single", supportsSimplified: true, supportsTraditional: true, isComponent: false)
        ]
        let result = BrowseGridComputationRules.compute(BrowseGridComputationInput(
            allItems: [one, two],
            metadataByCharacter: metadata,
            selectedCharacters: ["一", "二"],
            readingOrderCharacters: ["一", "二", "一"],
            minimumStroke: 0,
            maximumStroke: 30,
            radical: "none",
            structure: "none",
            scriptFilter: .any,
            sortMode: .readingOrder
        ))

        #expect(result.items.map(\.character) == ["一", "二"])
        #expect(result.readingOrder == ["一", "二", "一"])
        #expect(result.allCount == 3)
        #expect(result.componentCount == 1)
    }

    @Test("Filters and component sorting use immutable metadata")
    func filtersAndSortsComponents() {
        let lowUse = item("甲", strokes: 5, rank: 20, usage: 1)
        let highUse = item("乙", strokes: 5, rank: 30, usage: 8)
        let excluded = item("丙", strokes: 9, rank: 1, usage: 50)
        let metadata = Dictionary(uniqueKeysWithValues: [lowUse, highUse, excluded].map {
            ($0.character, BrowseGridItemMetadata(
                structure: "left-right",
                supportsSimplified: true,
                supportsTraditional: false,
                isComponent: $0.character != "丙"
            ))
        })
        let result = BrowseGridComputationRules.compute(BrowseGridComputationInput(
            allItems: [lowUse, highUse, excluded],
            metadataByCharacter: metadata,
            selectedCharacters: nil,
            readingOrderCharacters: nil,
            minimumStroke: 5,
            maximumStroke: 5,
            radical: "none",
            structure: "left-right",
            scriptFilter: .simplified,
            sortMode: .componentFrequency
        ))

        #expect(result.items.map(\.character) == ["乙", "甲"])
        #expect(result.allCount == 2)
        #expect(result.componentCount == 2)
    }

    private func item(_ character: String, strokes: Int, rank: Int, usage: Int) -> ComponentItem {
        ComponentItem(
            id: character,
            character: character,
            variant: nil,
            additionalVariants: [],
            pinyin: [],
            definition: "",
            decomposition: "",
            radical: "",
            strokes: strokes,
            relatedCharacters: [],
            etymologyHint: "",
            etymologyDetails: "",
            notes: "",
            usageCount: usage,
            freqPerMillion: 0,
            rank: rank,
            tier: 0
        )
    }
}
