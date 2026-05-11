import Foundation

enum PhraseDiscoveryCandidateTools {
    static func selectingAll(_ candidates: [PhraseDiscoveryCandidate], isSelected: Bool) -> [PhraseDiscoveryCandidate] {
        candidates.map { candidate in
            var candidate = candidate
            candidate.isSelected = isSelected
            return candidate
        }
    }

    static func deselecting(_ candidates: [PhraseDiscoveryCandidate], ids: Set<UUID>) -> [PhraseDiscoveryCandidate] {
        candidates.map { candidate in
            var candidate = candidate
            if ids.contains(candidate.id) {
                candidate.isSelected = false
            }
            return candidate
        }
    }

    static func mergingAddedResults(
        _ current: [PhraseDiscoveryCandidate],
        _ newItems: [PhraseDiscoveryCandidate]
    ) -> [PhraseDiscoveryCandidate] {
        var seen = Set<String>()
        var merged: [PhraseDiscoveryCandidate] = []
        for candidate in newItems + current {
            let phrase = candidate.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty, seen.insert(phrase).inserted else { continue }
            merged.append(candidate)
        }
        return merged
    }

    static func preparingForImport(_ candidates: [PhraseDiscoveryCandidate]) -> PhraseDiscoveryImportPreparation {
        var prepared: [PhraseDiscoveryPreparedCandidate] = []
        var skipped = 0
        var seen = Set<String>()

        for candidate in candidates {
            let phrase = candidate.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard PhraseDiscoveryParser.isValidPhrase(phrase), seen.insert(phrase).inserted else {
                skipped += 1
                continue
            }
            prepared.append(PhraseDiscoveryPreparedCandidate(candidate: candidate, phrase: phrase))
        }

        return PhraseDiscoveryImportPreparation(candidates: prepared, skippedCount: skipped)
    }
}

enum PhraseDiscoveryReader {
    static func read(_ text: String, existingWords: Set<String>) -> PhraseDiscoveryReadResult {
        read(PhraseDiscoveryParser.parse(text), existingWords: existingWords)
    }

    static func read(_ parsed: PhraseDiscoveryParseResult, existingWords: Set<String>) -> PhraseDiscoveryReadResult {
        let candidates = PhraseDiscoveryCandidateTools.selectingAll(parsed.candidates, isSelected: true)
        let stats = PhraseDiscoveryStats(
            totalParsed: parsed.totalParsed,
            duplicatesRemoved: parsed.duplicatesRemoved,
            alreadyExisting: existingWords.count,
            invalidLines: parsed.invalidLines
        )

        return PhraseDiscoveryReadResult(candidates: candidates, stats: stats)
    }
}
