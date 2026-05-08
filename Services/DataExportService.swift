import Foundation
import SQLite3

private let SQLITE_TRANSIENT_DATA_EXPORT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")
        defer { try? FileManager.default.removeItem(at: url) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let db { sqlite3_close(db) }
            throw NSError(domain: "Radix", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Failed to create dictionary export DB: \(message)"])
        }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE dictionary (
            character TEXT PRIMARY KEY,
            pinyin TEXT,
            definition TEXT,
            decomposition TEXT,
            radical TEXT,
            strokes INTEGER,
            raw_json TEXT NOT NULL
        );
        """
        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Failed to create dictionary table: \(String(cString: sqlite3_errmsg(db)))"])
        }

        let insertSQL = "INSERT INTO dictionary (character, pinyin, definition, decomposition, radical, strokes, raw_json) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare dictionary insert: \(String(cString: sqlite3_errmsg(db)))"])
        }
        defer { sqlite3_finalize(stmt) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        for record in records {
            let rawJSON = try String(data: encoder.encode(record.entry), encoding: .utf8) ?? ""
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (record.character as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 2, (record.pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 3, (record.definition as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 4, (record.decomposition as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 5, (record.radical as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            if let strokes = record.strokes {
                sqlite3_bind_int(stmt, 6, Int32(strokes))
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            sqlite3_bind_text(stmt, 7, (rawJSON as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw NSError(domain: "Radix", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Failed to insert dictionary row for \(record.character): \(String(cString: sqlite3_errmsg(db)))"])
            }
        }

        return try Data(contentsOf: url)
    }

    func exportMergedPhrasesDatabase(phrases: [PhraseItem]) throws -> Data {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")
        defer { try? FileManager.default.removeItem(at: url) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let db { sqlite3_close(db) }
            throw NSError(domain: "Radix", code: 2011, userInfo: [NSLocalizedDescriptionKey: "Failed to create phrase export DB: \(message)"])
        }
        defer { sqlite3_close(db) }

        let createSQL = "CREATE TABLE phrases (word TEXT PRIMARY KEY, pinyin TEXT, meanings TEXT, notes TEXT)"
        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2012, userInfo: [NSLocalizedDescriptionKey: "Failed to create phrases table: \(String(cString: sqlite3_errmsg(db)))"])
        }

        let insertSQL = "INSERT INTO phrases (word, pinyin, meanings, notes) VALUES (?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2013, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare phrase insert: \(String(cString: sqlite3_errmsg(db)))"])
        }
        defer { sqlite3_finalize(stmt) }

        for phrase in phrases {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (phrase.word as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 2, (phrase.pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 3, (phrase.meanings as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 4, (phrase.notes as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw NSError(domain: "Radix", code: 2014, userInfo: [NSLocalizedDescriptionKey: "Failed to insert phrase row for \(phrase.word): \(String(cString: sqlite3_errmsg(db)))"])
            }
        }

        return try Data(contentsOf: url)
    }

    func exportXcodeDataFiles(addPhrasesDBData: Data?) throws -> Data {
        var entries: [DataExportZipEntry] = []

        try appendFileEntry(
            to: &entries,
            archivePath: "enhanced_component_map_with_etymology.json",
            projectPath: "enhanced_component_map_with_etymology.json",
            bundleResource: "enhanced_component_map_with_etymology",
            bundleExtension: "json"
        )
        try appendOptionalFileEntry(
            to: &entries,
            archivePath: "component_map_changes.json",
            projectPath: "component_map_changes.json",
            bundleResource: "component_map_changes",
            bundleExtension: "json"
        )
        try appendFileEntry(
            to: &entries,
            archivePath: "phrases.db",
            projectPath: "phrases.db",
            bundleResource: "phrases",
            bundleExtension: "db"
        )

        if let addPhrasesDBData {
            entries.append(DataExportZipEntry(path: "phrases_add.db", data: addPhrasesDBData))
        } else {
            try appendOptionalFileEntry(
                to: &entries,
                archivePath: "phrases_add.db",
                projectPath: "phrases_add.db",
                bundleResource: "phrases_add",
                bundleExtension: "db"
            )
        }

        try appendFileEntry(
            to: &entries,
            archivePath: "Resources/character_strokes.db",
            projectPath: "Resources/character_strokes.db",
            bundleResource: "character_strokes",
            bundleExtension: "db"
        )
        try appendFileEntry(
            to: &entries,
            archivePath: "SUBTLEX-CH-CHR.txt",
            projectPath: "SUBTLEX-CH-CHR.txt",
            bundleResource: "SUBTLEX-CH-CHR",
            bundleExtension: "txt"
        )
        try appendOptionalFileEntry(
            to: &entries,
            archivePath: "Resources/subtlex_freq.json",
            projectPath: "Resources/subtlex_freq.json",
            bundleResource: "subtlex_freq",
            bundleExtension: "json"
        )
        try appendOptionalFileEntry(
            to: &entries,
            archivePath: "Resources/hanzi-writer.min.js",
            projectPath: "Resources/hanzi-writer.min.js",
            bundleResource: "hanzi-writer.min",
            bundleExtension: "js"
        )
        try appendOptionalFileEntry(
            to: &entries,
            archivePath: "strokes/u8fbc.json",
            projectPath: "strokes/u8fbc.json",
            bundleResource: "u8fbc",
            bundleExtension: "json",
            bundleSubdirectory: "strokes"
        )

        for license in ["ARPHICPL.TXT", "CEDICT_LICENSE.txt", "HANZI_WRITER_LICENSE.txt", "UNICODE_LICENSE.txt"] {
            let parts = splitFilename(license)
            try appendOptionalFileEntry(
                to: &entries,
                archivePath: "Resources/Licenses/\(license)",
                projectPath: "Resources/Licenses/\(license)",
                bundleResource: parts.name,
                bundleExtension: parts.extension,
                bundleSubdirectory: "Licenses"
            )
        }

        let manifest = xcodeDataFilesManifest(for: entries)
        entries.insert(DataExportZipEntry(path: "README.txt", data: Data(manifest.utf8)), at: 0)

        return try StoredZipArchive.makeData(entries: entries)
    }

    func exportProjectDirectoryArchive(createdAt: Date = Date()) throws -> Data {
        let fileManager = FileManager.default
        guard let projectRoot = ProjectLiveDataLocator.projectRoot(fileManager: fileManager) else {
            throw NSError(domain: "Radix", code: 2041, userInfo: [NSLocalizedDescriptionKey: "Unable to locate the Radix project folder on this device."])
        }

        let archiveRootName = "Radix-\(Self.archiveTimestamp.string(from: createdAt))"
        var entries: [DataExportZipEntry] = [
            DataExportZipEntry(
                path: "\(archiveRootName)/README_PROJECT_COPY.txt",
                data: Data(projectArchiveManifest(createdAt: createdAt, projectRoot: projectRoot).utf8)
            )
        ]

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: projectRoot,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: nil
        ) else {
            throw NSError(domain: "Radix", code: 2042, userInfo: [NSLocalizedDescriptionKey: "Unable to read the Radix project folder."])
        }

        var fileURLs: [URL] = []
        for case let url as URL in enumerator {
            let relativePath = url.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            guard shouldIncludeProjectArchivePath(relativePath) else {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let values = try url.resourceValues(forKeys: resourceKeys)
            if values.isDirectory == true {
                continue
            }
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                continue
            }
            fileURLs.append(url)
        }

        for url in fileURLs.sorted(by: { $0.path < $1.path }) {
            let relativePath = url.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            entries.append(
                DataExportZipEntry(
                    path: "\(archiveRootName)/\(relativePath)",
                    data: try Data(contentsOf: url)
                )
            )
        }

        return try StoredZipArchive.makeData(entries: entries, timestamp: createdAt)
    }

    private func appendFileEntry(
        to entries: inout [DataExportZipEntry],
        archivePath: String,
        projectPath: String,
        bundleResource: String,
        bundleExtension: String,
        bundleSubdirectory: String? = nil
    ) throws {
        guard let data = try readProjectOrBundleFile(
            projectPath: projectPath,
            bundleResource: bundleResource,
            bundleExtension: bundleExtension,
            bundleSubdirectory: bundleSubdirectory
        ) else {
            throw NSError(domain: "Radix", code: 2021, userInfo: [NSLocalizedDescriptionKey: "Missing required data file: \(archivePath)"])
        }
        entries.append(DataExportZipEntry(path: archivePath, data: data))
    }

    private func appendOptionalFileEntry(
        to entries: inout [DataExportZipEntry],
        archivePath: String,
        projectPath: String,
        bundleResource: String,
        bundleExtension: String,
        bundleSubdirectory: String? = nil
    ) throws {
        guard let data = try readProjectOrBundleFile(
            projectPath: projectPath,
            bundleResource: bundleResource,
            bundleExtension: bundleExtension,
            bundleSubdirectory: bundleSubdirectory
        ) else { return }
        entries.append(DataExportZipEntry(path: archivePath, data: data))
    }

    private func readProjectOrBundleFile(
        projectPath: String,
        bundleResource: String,
        bundleExtension: String,
        bundleSubdirectory: String?
    ) throws -> Data? {
        if let projectURL = ProjectLiveDataLocator.file(named: projectPath) {
            if let data = try? Data(contentsOf: projectURL) {
                return data
            }
        }
        if let url = Bundle.main.url(forResource: bundleResource, withExtension: bundleExtension, subdirectory: bundleSubdirectory) {
            return try Data(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: bundleResource, withExtension: bundleExtension) {
            return try Data(contentsOf: url)
        }
        return nil
    }

    private func splitFilename(_ filename: String) -> (name: String, extension: String) {
        let url = URL(fileURLWithPath: filename)
        return (url.deletingPathExtension().lastPathComponent, url.pathExtension)
    }

    private func xcodeDataFilesManifest(for entries: [DataExportZipEntry]) -> String {
        let listing = entries
            .map { "- \($0.path) (\($0.data.count) bytes)" }
            .joined(separator: "\n")
        return """
        Radix Xcode Data Files

        Copy these files into the matching paths in the Radix Xcode project when rebuilding the app from source.

        Included files:
        \(listing)
        """
    }

    private func projectArchiveManifest(createdAt: Date, projectRoot: URL) -> String {
        """
        Radix Project Copy

        Created: \(Self.displayTimestamp.string(from: createdAt))
        Source folder: \(projectRoot.path)

        This ZIP contains the local Radix project files needed to open and rebuild the app in Xcode, including Swift source, project metadata, resources, JSON files, and databases.
        """
    }

    private func shouldIncludeProjectArchivePath(_ relativePath: String) -> Bool {
        let components = relativePath.split(separator: "/").map(String.init)
        guard let last = components.last else { return false }
        let excludedNames: Set<String> = [
            ".DS_Store",
            ".codex_write_test",
            ".git",
            "DerivedData",
            "build"
        ]
        return !components.contains(where: excludedNames.contains) && !last.hasSuffix(".xcuserstate")
    }

    private static let archiveTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()

    private static let displayTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct DataExportZipEntry {
    let path: String
    let data: Data
}

private enum StoredZipArchive {
    static func makeData(entries: [DataExportZipEntry], timestamp: Date = Date()) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        let dosTimeDate = dosTimeDate(for: timestamp)

        for entry in entries {
            guard let nameData = entry.path.data(using: .utf8) else {
                throw NSError(domain: "Radix", code: 2031, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP entry name: \(entry.path)"])
            }
            let offset = UInt32(archive.count)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)

            archive.appendLittleEndian(UInt32(0x04034b50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0x0800))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(dosTimeDate.time)
            archive.appendLittleEndian(dosTimeDate.date)
            archive.appendLittleEndian(crc)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(UInt16(nameData.count))
            archive.appendLittleEndian(UInt16(0))
            archive.append(nameData)
            archive.append(entry.data)

            centralDirectory.appendLittleEndian(UInt32(0x02014b50))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(0x0800))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(dosTimeDate.time)
            centralDirectory.appendLittleEndian(dosTimeDate.date)
            centralDirectory.appendLittleEndian(crc)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(UInt16(nameData.count))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt32(0))
            centralDirectory.appendLittleEndian(offset)
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLittleEndian(UInt32(0x06054b50))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt32(centralDirectory.count))
        archive.appendLittleEndian(centralDirectoryOffset)
        archive.appendLittleEndian(UInt16(0))
        return archive
    }

    private static func dosTimeDate(for date: Date) -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((components.year ?? 1980), 1980) - 1980
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2

        let dosTime = UInt16((hour << 11) | (minute << 5) | second)
        let dosDate = UInt16((year << 9) | (month << 5) | day)
        return (dosTime, dosDate)
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xedb88320
            } else {
                crc >>= 1
            }
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
