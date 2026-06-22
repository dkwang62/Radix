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

struct DataExportService {
    func exportPortableBackup(_ package: UnifiedPackage) throws -> Data {
        try PortableBackupCodec().encode(package)
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
}
