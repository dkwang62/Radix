import Foundation

/// Transient results and available choices for component/root exploration.
struct RadixRootExplorerState {
    var derivatives: [ComponentItem] = []
    var derivativeTotal = 0
    var availableRadicals: [String] = ["none"]
    var availableStructures: [String] = ["none"]
}
