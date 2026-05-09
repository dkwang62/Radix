import Foundation

struct DictionaryExportRecord {
    let character: String
    let entry: RawComponentEntry
    let pinyin: String
    let definition: String
    let decomposition: String
    let radical: String
    let strokes: Int?
}

struct DataExportService {
    func exportPortableBackup(_ package: UnifiedPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(package)
    }

    func exportFullDataset(_ package: FullDatasetExportPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    func exportMergedDictionaryDatabase(records: [DictionaryExportRecord]) throws -> Data {
        try DataExportDatabaseBuilder.makeMergedDictionaryDatabase(records: records)
    }

    func exportMergedPhrasesDatabase(phrases: [PhraseItem]) throws -> Data {
        try DataExportDatabaseBuilder.makeMergedPhrasesDatabase(phrases: phrases)
    }

    func exportXcodeDataFiles(addPhrasesDBData: Data?) throws -> Data {
        try DataExportArchiveBuilder.makeXcodeDataFilesArchive(addPhrasesDBData: addPhrasesDBData)
    }

    func exportProjectDirectoryArchive(createdAt: Date = Date()) throws -> Data {
        try DataExportArchiveBuilder.makeProjectDirectoryArchive(createdAt: createdAt)
    }
}
