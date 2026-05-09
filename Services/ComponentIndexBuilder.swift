import Foundation

struct ComponentIndexSnapshot {
    let byCharacter: [String: ComponentItem]
    let allCharacters: [String]
    let knownCharacters: Set<String>
    let usedComponents: Set<String>
    let subtlexLoadedCount: Int
}

enum ComponentIndexBuilder {
    static func build(from raw: [String: RawComponentEntry], frequencies: [String: Double]) -> ComponentIndexSnapshot {
        let sortedByFreq = frequencies
            .filter { $0.key.count == 1 }
            .sorted { $0.value > $1.value }
            .prefix(6000)

        var charToRank: [String: Int] = [:]
        for (index, pair) in sortedByFreq.enumerated() {
            charToRank[pair.key] = index + 1
        }

        var mapped: [String: ComponentItem] = [:]
        mapped.reserveCapacity(raw.count)

        for (character, entry) in raw {
            let meta = entry.meta
            let lookupChar = ScriptTextConverter.simplified(character)
            let baseRank = charToRank[lookupChar]
            let usage = Set(entry.relatedCharacters.filter { $0.count == 1 }).count
            let tier = tierFor(rank: baseRank, usage: usage)

            let item = ComponentItem(
                id: character,
                character: character,
                variant: meta.variant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                additionalVariants: (meta.additionalVariants ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                pinyin: meta.pinyin?.list ?? [],
                definition: (meta.definition ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                decomposition: (meta.decomposition ?? meta.idc ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                radical: (meta.radical ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                strokes: meta.strokes?.intValue,
                relatedCharacters: entry.relatedCharacters,
                etymologyHint: meta.etymology?.hint?.text ?? "",
                etymologyDetails: meta.etymology?.details?.text ?? "",
                notes: meta.notes?.text ?? "",
                usageCount: usage,
                freqPerMillion: frequencies[lookupChar] ?? 0,
                rank: baseRank,
                tier: tier
            )
            mapped[character] = item
        }

        let allCharacters = mapped.keys.sorted()
        return ComponentIndexSnapshot(
            byCharacter: mapped,
            allCharacters: allCharacters,
            knownCharacters: Set(mapped.keys),
            usedComponents: ComponentDecompositionParser.usedComponents(from: mapped),
            subtlexLoadedCount: frequencies.count
        )
    }

    private static func tierFor(rank: Int?, usage: Int) -> Int {
        var assignedTier = 5
        if let rank {
            if rank <= 1500 { assignedTier = 1 }
            else if rank <= 3000 { assignedTier = 2 }
            else if rank <= 4000 { assignedTier = 3 }
            else if rank <= 6000 { assignedTier = 4 }
        }

        if assignedTier > 2 && usage >= 15 {
            assignedTier = 2
        }
        return assignedTier
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
