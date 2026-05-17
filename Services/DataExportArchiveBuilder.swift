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
        try appendOptionalFileEntry(
            to: &entries,
            archivePath: "Resources/japanese_character_strokes.db",
            projectPath: "Resources/japanese_character_strokes.db",
            bundleResource: "japanese_character_strokes",
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

}
