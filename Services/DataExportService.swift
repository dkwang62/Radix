import Foundation
import CryptoKit

struct DictionaryExportRecord {
    let character: String
    let entry: RawComponentEntry
    let pinyin: String
    let definition: String
    let decomposition: String
    let radical: String
    let strokes: Int?
}

struct BundledProjectArchiveInfo {
    let filename: String
    let byteCount: Int
    let generatedAt: Date?
    let sha256: String?

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    var displayGeneratedAt: String? {
        guard let generatedAt else { return nil }
        return Self.dateFormatter.string(from: generatedAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct BundledProjectArchiveManifest: Decodable {
    let filename: String
    let generatedAt: Date?
    let byteCount: Int
    let sha256: String?
}

struct PortableBackupDocument: @unchecked Sendable {
    let payload: PortableBackupPayload
    let sentenceDatabaseData: Data?
    let addedPhrasesDatabaseData: Data?

    var contentsSummary: String {
        let databaseSummary: String
        switch (sentenceDatabaseData, addedPhrasesDatabaseData) {
        case (.some, .some): databaseSummary = " Includes sentence and added-phrase databases."
        case (.some, .none): databaseSummary = " Includes the sentence database."
        case (.none, .some): databaseSummary = " Includes the added-phrase database."
        case (.none, .none): databaseSummary = ""
        }
        return payload.contentsSummary + databaseSummary
    }
}

private struct PortableBackupBundleManifest: Codable {
    struct FileEntry: Codable {
        let path: String
        let byteCount: Int
        let sha256: String

        enum CodingKeys: String, CodingKey {
            case path
            case byteCount = "byte_count"
            case sha256
        }
    }

    let schemaVersion: Int
    let generatedAt: Date
    let backupJSON: FileEntry
    let sentenceDatabase: FileEntry?
    let addedPhrasesDatabase: FileEntry?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case backupJSON = "backup_json"
        case sentenceDatabase = "sentence_database"
        case addedPhrasesDatabase = "added_phrases_database"
    }
}

struct DataExportService {
    private static let maximumBackupBundleBytes = 750 * 1_024 * 1_024
    private static let bundleManifestPath = "manifest.json"
    private static let backupJSONPath = "backup.json"
    private static let sentenceDatabasePath = "sentence_examples.sqlite"
    private static let addedPhrasesDatabasePath = "phrases_add.sqlite"

    func exportPortableBackup(_ package: UnifiedPackage) throws -> Data {
        try PortableBackupCodec().encode(package)
    }

    func exportPortableBackupBundle(
        package: UnifiedPackage,
        sentenceDatabaseData: Data?,
        addedPhrasesDatabaseData: Data?,
        generatedAt: Date = Date()
    ) throws -> Data {
        let backupData = try exportPortableBackup(package)
        var entries = [
            DataExportZipEntry(path: Self.backupJSONPath, data: backupData)
        ]

        if let sentenceDatabaseData, !sentenceDatabaseData.isEmpty {
            entries.append(DataExportZipEntry(path: Self.sentenceDatabasePath, data: sentenceDatabaseData))
        }
        if let addedPhrasesDatabaseData, !addedPhrasesDatabaseData.isEmpty {
            entries.append(DataExportZipEntry(path: Self.addedPhrasesDatabasePath, data: addedPhrasesDatabaseData))
        }

        let manifest = PortableBackupBundleManifest(
            schemaVersion: 1,
            generatedAt: generatedAt,
            backupJSON: manifestEntry(path: Self.backupJSONPath, data: backupData),
            sentenceDatabase: sentenceDatabaseData.map { manifestEntry(path: Self.sentenceDatabasePath, data: $0) },
            addedPhrasesDatabase: addedPhrasesDatabaseData.map { manifestEntry(path: Self.addedPhrasesDatabasePath, data: $0) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        entries.insert(DataExportZipEntry(path: Self.bundleManifestPath, data: manifestData), at: 0)

        let bundleData = try StoredZipArchive.makeData(entries: entries, timestamp: generatedAt)
        guard bundleData.count <= Self.maximumBackupBundleBytes else {
            throw PortableBackupCodecError.tooLarge
        }
        return bundleData
    }

    /// Reads a document-provider file through `NSFileCoordinator`. A direct
    /// `Data(contentsOf:)` can wait indefinitely when an iCloud file is only a
    /// placeholder, especially in the iPhone simulator.
    func readPortableBackup(at url: URL) throws -> Data {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            readResult = Result {
                let values = try coordinatedURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = values.fileSize, fileSize > PortableBackupCodec.maximumBackupBytes {
                    throw PortableBackupCodecError.tooLarge
                }
                return try Data(contentsOf: coordinatedURL, options: .mappedIfSafe)
            }
        }

        if let readResult {
            return try readResult.get()
        }
        if let coordinationError {
            throw coordinationError
        }
        throw NSError(domain: "RadixBackup", code: 2054, userInfo: [NSLocalizedDescriptionKey: "The selected iCloud file could not be opened."])
    }

    func readPortableBackupDocument(at url: URL) throws -> PortableBackupDocument {
        let data = try readBackupDocumentData(at: url)
        if let document = try? decodePortableBackupBundle(data) {
            return document
        }
        return PortableBackupDocument(
            payload: try PortableBackupCodec().decode(data),
            sentenceDatabaseData: nil,
            addedPhrasesDatabaseData: nil
        )
    }

    func writePortableBackup(_ data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeResult: Result<Void, Error>?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            writeResult = Result {
                try data.write(to: coordinatedURL, options: .atomic)
            }
        }

        if let writeResult {
            try writeResult.get()
            return
        }
        if let coordinationError {
            throw coordinationError
        }
        throw NSError(domain: "RadixBackup", code: 2055, userInfo: [NSLocalizedDescriptionKey: "The selected backup file could not be updated."])
    }

    func exportFullDataset(_ package: FullDatasetExportPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    func exportSentenceLibrary(_ package: SentenceLibraryExportPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    func decodeSentenceLibrary(_ data: Data) throws -> SentenceLibraryExportPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(SentenceLibraryExportPackage.self, from: data)
        guard package.schemaVersion == SentenceLibraryExportPackage.currentSchemaVersion else {
            throw NSError(
                domain: "RadixSentenceLibrary",
                code: 3201,
                userInfo: [NSLocalizedDescriptionKey: "This sentence library export is not compatible with this version of Radix."]
            )
        }
        return package
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

    func exportBundledProjectArchive() throws -> Data {
        guard let url = bundledProjectArchiveURL() else {
            throw NSError(domain: "Radix", code: 2041, userInfo: [NSLocalizedDescriptionKey: "The fixed Radix project ZIP is missing from this app build."])
        }
        let data = try Data(contentsOf: url)
        try validateBundledProjectArchive(data)
        return data
    }

    func exportBundledProjectManifest() throws -> Data {
        guard let url = bundledProjectArchiveManifestURL() else {
            throw NSError(domain: "Radix", code: 2044, userInfo: [NSLocalizedDescriptionKey: "The fixed Radix project manifest is missing from this app build."])
        }
        return try Data(contentsOf: url)
    }

    func exportBundledProjectReadme() throws -> Data {
        guard let info = bundledProjectArchiveInfo() else {
            throw NSError(domain: "Radix", code: 2045, userInfo: [NSLocalizedDescriptionKey: "The fixed Radix source package is missing from this app build."])
        }
        let generated = info.displayGeneratedAt ?? "Unknown"
        let checksum = info.sha256 ?? "Unavailable"
        let text = """
        Radix Project Source Package

        This file describes the fixed source package bundled with this Radix app build.

        Filename: \(info.filename)
        Size: \(info.displaySize)
        Generated: \(generated)
        SHA-256: \(checksum)

        The source package is intentionally fixed at build time. It is not made from a live folder on the device. Before a release, run Scripts/prepare_project_source_release.sh from the project directory to refresh the bundled package and manifest.

        The manifest JSON is the receipt for this package. Use it to verify byte count and checksum before sharing, archiving, or importing the source package on another Mac.
        """
        return Data(text.utf8)
    }

    func bundledProjectArchiveInfo() -> BundledProjectArchiveInfo? {
        if let manifest = bundledProjectArchiveManifest() {
            return BundledProjectArchiveInfo(
                filename: manifest.filename,
                byteCount: manifest.byteCount,
                generatedAt: manifest.generatedAt,
                sha256: manifest.sha256
            )
        }

        guard let url = bundledProjectArchiveURL() else { return nil }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return BundledProjectArchiveInfo(
            filename: url.lastPathComponent,
            byteCount: values?.fileSize ?? 0,
            generatedAt: nil,
            sha256: nil
        )
    }

    private func bundledProjectArchiveURL() -> URL? {
        Bundle.main.url(forResource: "RadixProjectSource", withExtension: "zip")
    }

    private func bundledProjectArchiveManifestURL() -> URL? {
        Bundle.main.url(forResource: "RadixProjectSourceManifest", withExtension: "json")
    }

    private func bundledProjectArchiveManifest() -> BundledProjectArchiveManifest? {
        guard let url = bundledProjectArchiveManifestURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BundledProjectArchiveManifest.self, from: data)
    }

    private func validateBundledProjectArchive(_ data: Data) throws {
        guard let manifest = bundledProjectArchiveManifest() else { return }
        if data.count != manifest.byteCount {
            throw NSError(
                domain: "Radix",
                code: 2042,
                userInfo: [NSLocalizedDescriptionKey: "The bundled Radix project ZIP does not match its release manifest. Refresh the project source ZIP before release."]
            )
        }

        guard let expectedSHA = manifest.sha256?.lowercased(), !expectedSHA.isEmpty else { return }
        let actualSHA = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        guard actualSHA == expectedSHA else {
            throw NSError(
                domain: "Radix",
                code: 2043,
                userInfo: [NSLocalizedDescriptionKey: "The bundled Radix project ZIP checksum does not match its release manifest. Refresh the project source ZIP before release."]
            )
        }
    }

    private func readBackupDocumentData(at url: URL) throws -> Data {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            readResult = Result {
                let values = try coordinatedURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = values.fileSize, fileSize > Self.maximumBackupBundleBytes {
                    throw PortableBackupCodecError.tooLarge
                }
                return try Data(contentsOf: coordinatedURL, options: .mappedIfSafe)
            }
        }

        if let readResult {
            return try readResult.get()
        }
        if let coordinationError {
            throw coordinationError
        }
        throw NSError(domain: "RadixBackup", code: 2054, userInfo: [NSLocalizedDescriptionKey: "The selected iCloud file could not be opened."])
    }

    private func decodePortableBackupBundle(_ data: Data) throws -> PortableBackupDocument {
        let entries = try StoredZipArchive.entriesByPath(in: data)
        guard let manifestData = entries[Self.bundleManifestPath],
              let backupData = entries[Self.backupJSONPath]
        else {
            throw PortableBackupCodecError.invalidDocument
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(PortableBackupBundleManifest.self, from: manifestData)
        try validate(backupData, against: manifest.backupJSON)
        let sentenceData = try dataIfPresent(
            entries: entries,
            manifestEntry: manifest.sentenceDatabase
        )
        let addedPhrasesData = try dataIfPresent(
            entries: entries,
            manifestEntry: manifest.addedPhrasesDatabase
        )

        return PortableBackupDocument(
            payload: try PortableBackupCodec().decode(backupData),
            sentenceDatabaseData: sentenceData,
            addedPhrasesDatabaseData: addedPhrasesData
        )
    }

    private func dataIfPresent(
        entries: [String: Data],
        manifestEntry: PortableBackupBundleManifest.FileEntry?
    ) throws -> Data? {
        guard let manifestEntry else { return nil }
        guard let data = entries[manifestEntry.path] else {
            throw PortableBackupCodecError.invalidDocument
        }
        try validate(data, against: manifestEntry)
        return data
    }

    private func validate(_ data: Data, against entry: PortableBackupBundleManifest.FileEntry) throws {
        guard data.count == entry.byteCount, sha256Hex(data) == entry.sha256.lowercased() else {
            throw NSError(domain: "RadixBackup", code: 2056, userInfo: [NSLocalizedDescriptionKey: "The backup package failed its integrity check."])
        }
    }

    private func manifestEntry(path: String, data: Data) -> PortableBackupBundleManifest.FileEntry {
        PortableBackupBundleManifest.FileEntry(
            path: path,
            byteCount: data.count,
            sha256: sha256Hex(data)
        )
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension PortableBackupPayload {
    var contentsSummary: String {
        switch self {
        case .unified(let package):
            let pageCount = package.collections?.count ?? 0
            let characterCount = package.dictionaryPatchOverlay.map { $0.customEntries.count + $0.patches.count + $0.deletions.count }
                ?? package.dictionaryOverlay?.upserts.count
                ?? package.dictionary?.count
                ?? 0
            return "Contains \(characterCount) character changes, \(package.phrases.count) phrases, and \(pageCount) saved pages."
        case .legacyDictionary(let dictionary):
            return "Contains \(dictionary.count) dictionary characters from an older Radix backup."
        }
    }
}
