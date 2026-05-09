import Foundation

enum ComponentOverlayBuilder {
    static func makeOverlay(base: [String: RawComponentEntry], effective: [String: RawComponentEntry]) -> DictionaryOverlayPackage {
        var upserts: [String: RawComponentEntry] = [:]
        var deletions: [String] = []

        for (character, entry) in effective where base[character] != entry {
            upserts[character] = entry
        }

        for character in base.keys where effective[character] == nil {
            deletions.append(character)
        }

        return DictionaryOverlayPackage(schemaVersion: 2, upserts: upserts, deletions: deletions.sorted())
    }

    static func mergedOverlayEntry(_ overlay: RawComponentEntry, onto base: RawComponentEntry) -> RawComponentEntry {
        let baseMeta = base.meta
        let overlayMeta = overlay.meta
        let mergedPinyin = overlayMeta.pinyin ?? baseMeta.pinyin
        let mergedDefinition = overlayMeta.definition ?? baseMeta.definition
        let mergedDecomposition = overlayMeta.decomposition ?? baseMeta.decomposition
        let mergedIDC = overlayMeta.idc ?? baseMeta.idc
        let mergedRadical = overlayMeta.radical ?? baseMeta.radical
        let mergedStrokes = overlayMeta.strokes ?? baseMeta.strokes
        let mergedVariant = overlayMeta.variant ?? baseMeta.variant
        let mergedCompounds = overlayMeta.compounds ?? baseMeta.compounds
        let mergedEtymology = overlayMeta.etymology ?? baseMeta.etymology
        let mergedNotes = overlayMeta.notes ?? baseMeta.notes

        var mergedAdditional: [String] = baseMeta.additionalVariants ?? []
        for variant in overlayMeta.additionalVariants ?? [] where !mergedAdditional.contains(variant) {
            mergedAdditional.append(variant)
        }

        let mergedMeta = RawMeta(
            variant: mergedVariant,
            additionalVariants: mergedAdditional.isEmpty ? nil : mergedAdditional,
            pinyin: mergedPinyin,
            definition: mergedDefinition,
            decomposition: mergedDecomposition,
            idc: mergedIDC,
            radical: mergedRadical,
            strokes: mergedStrokes,
            compounds: mergedCompounds,
            etymology: mergedEtymology,
            notes: mergedNotes
        )

        return RawComponentEntry(
            relatedCharacters: overlay.relatedCharacters,
            meta: mergedMeta
        )
    }

    static func makePatch(character: String, base: RawComponentEntry, edited: RawComponentEntry, updatedAt: Date) -> DictionaryEntryPatch {
        let baseMeta = base.meta
        let editedMeta = edited.meta
        let metaPatch = RawMetaPatch(
            variant: editedMeta.variant != baseMeta.variant ? editedMeta.variant : nil,
            additionalVariants: editedMeta.additionalVariants != baseMeta.additionalVariants ? editedMeta.additionalVariants : nil,
            pinyin: editedMeta.pinyin != baseMeta.pinyin ? editedMeta.pinyin : nil,
            definition: editedMeta.definition != baseMeta.definition ? editedMeta.definition : nil,
            decomposition: editedMeta.decomposition != baseMeta.decomposition ? editedMeta.decomposition : nil,
            idc: editedMeta.idc != baseMeta.idc ? editedMeta.idc : nil,
            radical: editedMeta.radical != baseMeta.radical ? editedMeta.radical : nil,
            strokes: editedMeta.strokes != baseMeta.strokes ? editedMeta.strokes : nil,
            compounds: editedMeta.compounds != baseMeta.compounds ? editedMeta.compounds : nil,
            etymology: editedMeta.etymology != baseMeta.etymology ? editedMeta.etymology : nil,
            notes: editedMeta.notes != baseMeta.notes ? editedMeta.notes : nil
        )

        return DictionaryEntryPatch(
            character: character,
            relatedCharacters: edited.relatedCharacters != base.relatedCharacters ? edited.relatedCharacters : nil,
            meta: metaPatch,
            updatedAt: updatedAt
        )
    }

    static func applyPatch(_ patch: DictionaryEntryPatch, to base: RawComponentEntry) -> RawComponentEntry {
        let baseMeta = base.meta
        let patchMeta = patch.meta
        let meta = RawMeta(
            variant: patchMeta.variant ?? baseMeta.variant,
            additionalVariants: patchMeta.additionalVariants ?? baseMeta.additionalVariants,
            pinyin: patchMeta.pinyin ?? baseMeta.pinyin,
            definition: patchMeta.definition ?? baseMeta.definition,
            decomposition: patchMeta.decomposition ?? baseMeta.decomposition,
            idc: patchMeta.idc ?? baseMeta.idc,
            radical: patchMeta.radical ?? baseMeta.radical,
            strokes: patchMeta.strokes ?? baseMeta.strokes,
            compounds: patchMeta.compounds ?? baseMeta.compounds,
            etymology: patchMeta.etymology ?? baseMeta.etymology,
            notes: patchMeta.notes ?? baseMeta.notes
        )
        return RawComponentEntry(
            relatedCharacters: patch.relatedCharacters ?? base.relatedCharacters,
            meta: meta
        )
    }
}
