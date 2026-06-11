import Foundation

enum RadixSharedImageImport {
    static let appGroupIdentifier = "group.com.desmond.radix"
    static let incomingDirectoryName = "IncomingSharedImages"

    static var importURL: URL {
        URL(string: "radix://import-shared-image")!
    }

    static func isImportURL(_ url: URL) -> Bool {
        url.scheme == "radix" && url.host == "import-shared-image"
    }

    static func incomingDirectory(create: Bool = false) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        let directory = container.appendingPathComponent(incomingDirectoryName, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func makeIncomingImageURL(fileExtension: String) -> URL? {
        let cleanedExtension = fileExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = cleanedExtension.isEmpty ? "jpg" : cleanedExtension
        return incomingDirectory(create: true)?
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    static func pendingImageURLs() -> [URL] {
        guard let directory = incomingDirectory() else { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return leftDate < rightDate
        }
    }
}
