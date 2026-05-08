import Foundation

enum BackupSummaryBuilder {
    static func phraseHasCoreEdit(phrase: PhraseItem, basePhrase: PhraseItem?) -> Bool {
        guard let basePhrase else { return false }
        return trimmed(phrase.pinyin) != trimmed(basePhrase.pinyin)
            || trimmed(phrase.meanings) != trimmed(basePhrase.meanings)
    }

    static func dictionaryCoreFieldsChanged(base: RawComponentEntry?, edited: RawComponentEntry?) -> Bool {
        guard let base, let edited else { return false }

        return edited.relatedCharacters != base.relatedCharacters
            || edited.meta.variant != base.meta.variant
            || edited.meta.additionalVariants != base.meta.additionalVariants
            || edited.meta.pinyin != base.meta.pinyin
            || edited.meta.definition != base.meta.definition
            || edited.meta.decomposition != base.meta.decomposition
            || edited.meta.idc != base.meta.idc
            || edited.meta.radical != base.meta.radical
            || edited.meta.strokes != base.meta.strokes
            || edited.meta.compounds != base.meta.compounds
            || edited.meta.etymology != base.meta.etymology
    }

    static func dictionaryNotesChangedAndNonEmpty(base: RawComponentEntry?, edited: RawComponentEntry?) -> Bool {
        guard let edited else { return false }
        guard edited.meta.notes != base?.meta.notes else { return false }
        return !notesText(edited.meta.notes).isEmpty
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func notesText(_ notes: StringOrMany?) -> String {
        notes?.list.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
