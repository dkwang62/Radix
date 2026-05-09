import Foundation

enum DataExportArchiveBuilder {
    static func makeXcodeDataFilesArchive(addPhrasesDBData: Data?) throws -> Data {
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

    static func makeProjectDirectoryArchive(createdAt: Date = Date()) throws -> Data {
        let fileManager = FileManager.default
        guard let projectRoot = ProjectLiveDataLocator.projectRoot(fileManager: fileManager) else {
            throw NSError(domain: "Radix", code: 2041, userInfo: [NSLocalizedDescriptionKey: "Unable to locate the Radix project folder on this device."])
        }

        let archiveRootName = "Radix-\(archiveTimestamp.string(from: createdAt))"
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

    private static func appendFileEntry(
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

    private static func appendOptionalFileEntry(
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

    private static func readProjectOrBundleFile(
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

    private static func splitFilename(_ filename: String) -> (name: String, extension: String) {
        let url = URL(fileURLWithPath: filename)
        return (url.deletingPathExtension().lastPathComponent, url.pathExtension)
    }

    private static func xcodeDataFilesManifest(for entries: [DataExportZipEntry]) -> String {
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

    private static func projectArchiveManifest(createdAt: Date, projectRoot: URL) -> String {
        """
        Radix Project Copy

        Created: \(displayTimestamp.string(from: createdAt))
        Source folder: \(projectRoot.path)

        This ZIP contains the local Radix project files needed to open and rebuild the app in Xcode, including Swift source, project metadata, resources, JSON files, and databases.
        """
    }

    private static func shouldIncludeProjectArchivePath(_ relativePath: String) -> Bool {
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
