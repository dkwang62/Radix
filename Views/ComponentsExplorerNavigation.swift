import SwiftUI

extension ComponentsExplorerShell {
    func pivot(to character: String, selectAfter: Bool) {
        if selectAfter {
            seed = character
            store.pushRootBreadcrumb(character)
            store.select(character: character)
            store.loadSharedComponentPeers(for: character)
            store.loadSharedPeersByComponent(for: character)
            store.loadRootDerivatives(for: character)
        } else {
            store.preview(character: character)
        }
        store.showComponentHelp = false
    }

    func startRootExploration(with character: String, remember: Bool) {
        seed = character
        store.preview(character: character)
        if remember {
            store.pushRootBreadcrumb(character)
            store.select(character: character)
        }
        store.loadSharedComponentPeers(for: character)
        store.loadSharedPeersByComponent(for: character)
        store.loadRootDerivatives(for: character)
        store.showComponentHelp = false
    }

    func reloadRootContextIfNeeded() {
        let start = seed
        guard !start.isEmpty else { return }
        store.loadSharedComponentPeers(for: start)
        store.loadSharedPeersByComponent(for: start)
        store.loadRootDerivatives(for: start)
    }

    func syncSeed(with character: String?, resetHistory: Bool = false) {
        guard let character, character != seed else { return }
        if resetHistory {
            store.resetRootBreadcrumb(to: character)
        } else {
            store.pushRootBreadcrumb(character)
        }
        seed = character
        store.loadSharedComponentPeers(for: character)
        store.loadSharedPeersByComponent(for: character)
        store.loadRootDerivatives(for: character)
        store.showComponentHelp = false
    }

    func stepBreadcrumb(_ delta: Int) {
        guard let target = store.stepRootBreadcrumb(by: delta) else { return }
        seed = target
        store.select(character: target)
        store.loadSharedComponentPeers(for: target)
        store.loadSharedPeersByComponent(for: target)
        store.loadRootDerivatives(for: target)
    }

    func jumpToBreadcrumb(index: Int) {
        let delta = index - store.rootBreadcrumbIndex
        stepBreadcrumb(delta)
    }
}
