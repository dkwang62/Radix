import Foundation

/// Results and presentation state for character lineage exploration.
struct RadixLineageState {
    var parents: [ComponentItem] = []
    var derivatives: [ComponentItem] = []
    var sortedDerivatives: [ComponentItem] = []
    var phoneticFamily: [ComponentItem] = []
    var semanticFamily: [ComponentItem] = []
    var structureAnalysis: ComponentStructureAnalysis?
    var sortMode: LineageSortMode = .usage
    var page = 0
}
