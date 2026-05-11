import Foundation

/*
 RADIX STORE — ROOTS CACHE
 ==========================
 Loads and caches shared component peers, peers-by-component, and
 root derivatives for the Lineage (Components) tab.
 All @Published state and cache storage remain in RadixStore.swift.
*/

extension RadixStore {

    // MARK: - Peers loading

    func loadSharedComponentPeers(for character: String) {
        sharedComponentPeers = componentRepo.sharedComponentPeers(for: character, scriptFilter: scriptFilter)
            .filter(rootFilterPredicate)
            .sorted(by: usageSortPredicate)
    }

    func loadSharedPeersByComponent(for character: String) {
        let raw = componentRepo.sharedPeersByComponent(for: character, scriptFilter: scriptFilter)
        var filtered: [String: [ComponentItem]] = [:]
        for (key, list) in raw {
            let keep = list
                .filter(rootFilterPredicate)
                .sorted(by: usageSortPredicate)
            if !keep.isEmpty { filtered[key] = keep }
        }
        sharedPeersByComponent = filtered
    }

    // MARK: - Root derivatives

    func rootInitialGridItems(limit: Int = Int.max) -> (items: [ComponentItem], total: Int) {
        let filtered = allCharactersCache
            .filter(rootFilterPredicate)
            .filter { item in
                switch scriptFilter {
                case .any:         return true
                case .simplified:  return componentRepo.isSimplifiedForGrid(item.character)
                case .traditional: return componentRepo.isTraditionalForGrid(item.character)
                }
            }
            .sorted(by: frequencySortPredicate)
        return (Array(filtered.prefix(limit)), filtered.count)
    }

    func loadRootDerivatives(for character: String) {
        let result = rootDerivatives(for: character)
        rootDerivatives = result.items
        rootDerivativesTotal = result.total
    }

    func rootDerivatives(for character: String) -> (items: [ComponentItem], total: Int) {
        let key = RootsCacheKey(
            character: character,
            script: scriptFilter,
            minStroke: rootMinStroke,
            maxStroke: rootMaxStroke,
            radical: rootRadicalFilter,
            structure: rootStructureFilter
        )
        if let cached = rootsDerivativesCache[key] {
            return (cached.items, cached.total)
        }

        let preferred  = componentRepo.related(for: character, scriptFilter: scriptFilter, max: 8000)
        let relatedAny = componentRepo.related(for: character, scriptFilter: .any, max: 8000)
        let universe   = componentRepo.containingCharacters(for: character, scriptFilter: scriptFilter, max: 8000)
        let universeAny = componentRepo.containingCharacters(for: character, scriptFilter: .any, max: 8000)
        let rawIDs = componentRepo.entry(for: character)?.relatedCharacters ?? []
        let rawFromIDs = rawIDs
            .compactMap { componentRepo.byCharacter[$0] }
            .filter { componentRepo.matchesScriptFilter(item: $0, filter: scriptFilter) }

        let baseSet: [ComponentItem] = {
            if !preferred.isEmpty   { return preferred }
            if !relatedAny.isEmpty  { return relatedAny }
            if !rawFromIDs.isEmpty  { return rawFromIDs }
            if !universe.isEmpty    { return universe }
            return universeAny
        }()

        let filtered = baseSet.filter(rootFilterPredicate)
        let finalSet = filtered.isEmpty ? baseSet : filtered
        let sorted   = finalSet.sorted(by: frequencySortPredicate)
        let limited  = Array(sorted.prefix(500))
        rootsDerivativesCache[key] = RootsDerivativesCacheValue(items: limited, total: sorted.count)
        return (limited, sorted.count)
    }
}
