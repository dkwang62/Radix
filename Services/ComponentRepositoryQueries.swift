import Foundation

extension ComponentRepository {
    func search(query: String, scriptFilter: ScriptFilter, limit: Int = 300) -> [ComponentItem] {
        ComponentSearchEngine.search(
            query: query,
            index: searchIndex,
            limit: limit
        ) { matchesScriptFilter(item: $0, filter: scriptFilter) }
    }

    func related(for character: String, scriptFilter: ScriptFilter, max: Int = 120) -> [ComponentItem] {
        guard let base = byCharacter[character] else { return [] }
        return base.relatedCharacters
            .prefix(max)
            .compactMap { byCharacter[$0] }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
    }

    /// Fallback: find characters whose decomposition contains the given character, even if the base isn't marked as a component.
    func relatedByContainment(for character: String, scriptFilter: ScriptFilter, max: Int = 200) -> [ComponentItem] {
        let results = byCharacter.values
            .filter { $0.character != character && !$0.decomposition.isEmpty }
            .filter { item in
                decompositionParts(from: item.decomposition, excluding: item.character).contains(character)
            }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
            .sorted(by: frequencyThenUsageSort)
        return Array(results.prefix(max))
    }

    /// Full set of characters that contain the given character anywhere in their decomposition.
    func containingCharacters(for character: String, scriptFilter: ScriptFilter, max: Int = 8000) -> [ComponentItem] {
        let results = byCharacter.values
            .filter { $0.character != character && !$0.decomposition.isEmpty }
            .filter { item in
                decompositionParts(from: item.decomposition, excluding: item.character).contains(character)
            }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
            .sorted(by: frequencyThenUsageSort)
        return Array(results.prefix(max))
    }

    func sharedComponentPeers(for character: String, scriptFilter: ScriptFilter, limit: Int = 300) -> [ComponentItem] {
        guard let base = byCharacter[character] else { return [] }
        let parts = Set(decompositionParts(from: base.decomposition, excluding: character))
        guard !parts.isEmpty else { return [] }

        let peers = byCharacter.values
            .filter { $0.character != character && !$0.decomposition.isEmpty }
            .filter { item in
                let compSet = Set(decompositionParts(from: item.decomposition, excluding: item.character))
                return !parts.isDisjoint(with: compSet)
            }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
            .sorted(by: frequencyThenUsageSort)

        return Array(peers.prefix(limit))
    }

    func confusablePeers(for character: String, scriptFilter: ScriptFilter, limit: Int = 80) -> [ComponentItem] {
        if confusablePeerCache[scriptFilter] == nil {
            confusablePeerCache[scriptFilter] = buildConfusablePeerMap(scriptFilter: scriptFilter)
        }

        return Array((confusablePeerCache[scriptFilter]?[character] ?? [])
            .prefix(limit)
            .compactMap { byCharacter[$0] })
    }

    func sharedPeersByComponent(for character: String, scriptFilter: ScriptFilter, perComponentLimit: Int = 120) -> [String: [ComponentItem]] {
        guard let base = byCharacter[character] else { return [:] }
        var parts = Set(decompositionParts(from: base.decomposition, excluding: character))
        // If the character has no decomposition parts, fall back to treating the character itself as a component.
        if parts.isEmpty { parts = [character] }

        var result: [String: [ComponentItem]] = [:]
        for comp in parts {
            let matches = byCharacter.values
                .filter { $0.character != character && !$0.decomposition.isEmpty }
                .filter { item in
                    let compSet = Set(decompositionParts(from: item.decomposition, excluding: item.character))
                    return compSet.contains(comp)
                }
                .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
                .sorted(by: frequencyThenUsageSort)

            result[comp] = Array(matches.prefix(perComponentLimit))
        }

        return result
    }

    func components(for character: String, scriptFilter: ScriptFilter) -> [ComponentItem] {
        guard let base = byCharacter[character] else { return [] }
        let parts = decompositionParts(from: base.decomposition, excluding: character)
        return parts.compactMap { byCharacter[$0] }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }
    }

    func analyzeStructure(for character: String) -> ComponentStructureAnalysis? {
        guard let base = byCharacter[character] else { return nil }
        let decomposition = base.decomposition
        guard let first = decomposition.first, first == "⿰" || first == "⿱" else { return nil }

        let semantic = base.radical.isEmpty || base.radical == "—" ? nil : base.radical
        let parts = decompositionParts(from: decomposition, excluding: character)

        guard let semantic else {
            return ComponentStructureAnalysis(semantic: nil, phonetic: nil, phoneticPinyin: nil, isSoundMatch: false)
        }

        let phonetic = parts.first(where: { $0 != semantic })
        let phoneticPinyin = phonetic.flatMap { byCharacter[$0]?.pinyin.first }
        let sourcePinyin = base.pinyin.first

        return ComponentStructureAnalysis(
            semantic: semantic,
            phonetic: phonetic,
            phoneticPinyin: phoneticPinyin,
            isSoundMatch: matchesSound(lhs: sourcePinyin, rhs: phoneticPinyin)
        )
    }

    func pronunciationFamily(for character: String, limit: Int = 8) -> [String] {
        guard let analysis = analyzeStructure(for: character),
              let phonetic = analysis.phonetic,
              !phonetic.isEmpty
        else { return [] }

        let out = byCharacter.values
            .filter { $0.character != character && $0.decomposition.contains(phonetic) }
            .sorted(by: frequencyThenUsageSort)
            .map(\.character)
        return Array(out.prefix(limit))
    }

    func semanticFamily(for character: String, limit: Int = 8) -> [String] {
        guard let radical = byCharacter[character]?.radical, !radical.isEmpty, radical != "—" else {
            return []
        }
        let out = byCharacter.values
            .filter { $0.character != character && $0.radical == radical }
            .sorted(by: frequencyThenUsageSort)
            .map(\.character)
        return Array(out.prefix(limit))
    }

    func searchDefinitions(query: String, scriptFilter: ScriptFilter, limit: Int = 120, isStrict: Bool = false) -> [ComponentItem] {
        ComponentSearchEngine.searchDefinitions(
            query: query,
            index: searchIndex,
            limit: limit,
            isStrict: isStrict
        ) { matchesScriptFilter(item: $0, filter: scriptFilter) }
    }

    func hasCharacter(_ character: String) -> Bool {
        byCharacter[character] != nil
    }

    /// Returns all script variants for a character — explicit variants first, then CFTransform fallback.
    func allVariants(for character: String) -> [String] {
        guard let item = byCharacter[character] else { return [] }
        let explicit = item.allVariants.filter { $0 != character && byCharacter[$0] != nil }
        if !explicit.isEmpty { return explicit }
        // Fallback to CFStringTransform.
        var result: [String] = []
        let s = toSimplified(character)
        let t = toTraditional(character)
        if s != character, byCharacter[s] != nil { result.append(s) }
        if t != character, byCharacter[t] != nil, !result.contains(t) { result.append(t) }
        return result
    }

    func counterpart(for character: String) -> String? {
        allVariants(for: character).first
    }

    func simplifiedText(_ value: String) -> String {
        toSimplified(value)
    }

    func traditionalText(_ value: String) -> String {
        toTraditional(value)
    }

    func availableRadicals() -> [String] {
        let radicals = Set(byCharacter.values.map(\.radical).filter { !$0.isEmpty && $0 != "—" })
        return radicals.sorted { lhs, rhs in
            let lhsStrokes = byCharacter[lhs]?.strokes ?? Int.max
            let rhsStrokes = byCharacter[rhs]?.strokes ?? Int.max
            if lhsStrokes != rhsStrokes { return lhsStrokes < rhsStrokes }
            return lhs < rhs
        }
    }

    func availableStructures() -> [String] {
        let structures = Set(byCharacter.values.map { structureKey(for: $0) })
        return structures.sorted()
    }

    func structureKey(for item: ComponentItem) -> String {
        decompositionParser.structureKey(for: item.decomposition)
    }

    func isSimplifiedForGrid(_ value: String) -> Bool {
        scriptClass(for: value) != .traditionalOnly
    }

    func isTraditionalForGrid(_ value: String) -> Bool {
        scriptClass(for: value) != .simplifiedOnly
    }

    func isUsedComponent(_ character: String) -> Bool {
        usedComponents.contains(character)
    }

    func matchesScriptFilter(item: ComponentItem, filter: ScriptFilter) -> Bool {
        switch filter {
        case .any:
            return true
        case .simplified:
            return isSimplified(item.character)
        case .traditional:
            return isTraditional(item.character)
        }
    }

    private func scriptClass(for value: String) -> ComponentScriptClass {
        scriptClassifier.scriptClass(for: value, in: byCharacter)
    }

    private func isSimplified(_ value: String) -> Bool {
        scriptClass(for: value) != .traditionalOnly
    }

    private func isTraditional(_ value: String) -> Bool {
        scriptClass(for: value) != .simplifiedOnly
    }

    private func toSimplified(_ value: String) -> String {
        ScriptTextConverter.simplified(value)
    }

    private func toTraditional(_ value: String) -> String {
        ScriptTextConverter.traditional(value)
    }

    private func decompositionParts(from decomposition: String, excluding character: String) -> [String] {
        decompositionParser.parts(
            from: decomposition,
            excluding: character,
            knownCharacters: knownCharacters
        )
    }

    private func matchesSound(lhs: String?, rhs: String?) -> Bool {
        guard let lhs, let rhs, !lhs.isEmpty, !rhs.isEmpty else { return false }
        return normalizePinyin(lhs) == normalizePinyin(rhs)
    }

    private func normalizePinyin(_ value: String) -> String {
        let mutable = NSMutableString(string: value.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let stripped = mutable as String
        return stripped.filter { $0.isLetter }
    }

    private func frequencyThenUsageSort(_ lhs: ComponentItem, _ rhs: ComponentItem) -> Bool {
        let lRank = lhs.rank ?? 999999
        let rRank = rhs.rank ?? 999999
        if lRank != rRank { return lRank < rRank }

        if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
        return lhs.character < rhs.character
    }

    private func buildConfusablePeerMap(scriptFilter: ScriptFilter) -> [String: [String]] {
        let eligibleItems = byCharacter.values
            .filter { $0.character.count == 1 }
            .filter { !$0.decomposition.isEmpty }
            .filter { matchesScriptFilter(item: $0, filter: scriptFilter) }

        let rawComponentsByCharacter = Dictionary(uniqueKeysWithValues: eligibleItems.map { item in
            (
                item.character,
                Set(decompositionParts(from: item.decomposition, excluding: item.character))
            )
        })
        let componentUsage = rawComponentsByCharacter.values.reduce(into: [String: Int]()) { counts, components in
            for component in components {
                counts[component, default: 0] += 1
            }
        }

        func qualifies(_ component: String) -> Bool {
            guard let item = byCharacter[component] else { return false }
            guard !Self.lowSignalConfusableComponents.contains(component) else { return false }
            guard !item.definition.localizedCaseInsensitiveContains("radical") else { return false }
            let usage = componentUsage[component, default: 0]
            guard usage >= 2 && usage <= 180 else { return false }
            if let strokes = item.strokes, strokes <= 2 { return false }
            return true
        }

        let componentsByCharacter = rawComponentsByCharacter.mapValues { components in
            components.filter(qualifies)
        }
        let inverted = componentsByCharacter.reduce(into: [String: [String]]()) { index, pair in
            let (character, components) = pair
            for component in components {
                index[component, default: []].append(character)
            }
        }

        var output: [String: [String]] = [:]
        for item in eligibleItems {
            let sourceComponents = componentsByCharacter[item.character] ?? []
            guard !sourceComponents.isEmpty else { continue }

            var scores: [String: Int] = [:]
            for component in sourceComponents {
                for peer in inverted[component, default: []] where peer != item.character {
                    scores[peer, default: 0] += 10
                }
            }

            let variants = Set(allVariants(for: item.character))
            let sourceStructure = structureKey(for: item)
            let ranked = scores.compactMap { peerCharacter, baseScore -> (item: ComponentItem, score: Int)? in
                guard !variants.contains(peerCharacter),
                      let peer = byCharacter[peerCharacter],
                      matchesScriptFilter(item: peer, filter: scriptFilter)
                else { return nil }

                let peerComponents = componentsByCharacter[peerCharacter] ?? []
                let shared = sourceComponents.intersection(peerComponents)
                guard !shared.isEmpty else { return nil }

                var score = baseScore
                if sourceStructure != "None", sourceStructure == structureKey(for: peer) {
                    score += 4
                }
                if let sourceStrokes = item.strokes, let peerStrokes = peer.strokes {
                    let distance = abs(sourceStrokes - peerStrokes)
                    if distance <= 2 {
                        score += 3
                    } else if distance >= 7 {
                        score -= 4
                    }
                }
                if item.radical == peer.radical, shared.count == 1 {
                    score -= 5
                }
                if shared.count >= 2 {
                    score += 6
                }

                guard score >= 8 else { return nil }
                return (peer, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return frequencyThenUsageSort(lhs.item, rhs.item)
            }

            output[item.character] = ranked.map(\.item.character)
        }

        return output
    }

    private static let lowSignalConfusableComponents: Set<String> = [
        "一", "丨", "丶", "丿", "乙", "亅", "二", "十", "厂", "匚", "卜", "人", "亻",
        "儿", "入", "八", "冂", "冖", "冫", "几", "凵", "刀", "刂", "力", "勹", "匕",
        "匸", "卩", "又", "口", "囗", "土", "士", "夂", "夊", "夕", "大", "女", "子",
        "宀", "寸", "小", "尢", "尸", "屮", "山", "巛", "工", "己", "巾", "干", "幺",
        "广", "廴", "廾", "弋", "弓", "彐", "彡", "彳", "心", "忄", "戈", "户", "手",
        "扌", "支", "攵", "文", "斗", "斤", "方", "日", "曰", "月", "木", "欠", "止",
        "水", "氵", "火", "灬", "爪", "爫", "牛", "牜", "犬", "犭", "玉", "王", "示",
        "礻", "糸", "纟", "艹", "衣", "衤", "言", "讠", "辶", "邑", "阝", "金", "钅",
        "門", "门", "頁", "页", "風", "风", "食", "饣", "馬", "马", "魚", "鱼", "鳥",
        "鸟"
    ]
}
