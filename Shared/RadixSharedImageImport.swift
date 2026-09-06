import Foundation

enum RadixSharedImportKind: CaseIterable {
    case text
    case image
}

struct RadixSharedImportQueueItem: Identifiable {
    let id: UUID
    let kind: RadixSharedImportKind
    let fileURL: URL
}

struct RadixSharedImportFailure: Identifiable {
    let item: RadixSharedImportQueueItem
    let message: String

    var id: UUID { item.id }
}

enum RadixSharedImageImport {
    static let appGroupIdentifier = "group.com.desmond.radix"
    static let incomingDirectoryName = "IncomingSharedImages"
    static let incomingTextDirectoryName = "IncomingSharedText"
    private static let processingImageDirectoryName = "ProcessingSharedImages"
    private static let processingTextDirectoryName = "ProcessingSharedText"
    private static let failedImageDirectoryName = "FailedSharedImages"
    private static let failedTextDirectoryName = "FailedSharedText"
    private static let processIdentifier = UUID().uuidString

    static var importURL: URL {
        URL(string: "radix://import-shared-image")!
    }

    static var textImportURL: URL {
        URL(string: "radix://import-shared-text")!
    }

    static func isImportURL(_ url: URL) -> Bool {
        url.scheme == "radix" && url.host == "import-shared-image"
    }

    static func isTextImportURL(_ url: URL) -> Bool {
        url.scheme == "radix" && url.host == "import-shared-text"
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

    static func incomingTextDirectory(create: Bool = false) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        let directory = container.appendingPathComponent(incomingTextDirectoryName, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func makeIncomingTextURL() -> URL? {
        incomingTextDirectory(create: true)?
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
    }

    static func pendingImageURLs() -> [URL] {
        guard let directory = incomingDirectory() else { return [] }
        return sortedPendingURLs(in: directory)
    }

    static func pendingTextURLs() -> [URL] {
        guard let directory = incomingTextDirectory() else { return [] }
        return sortedPendingURLs(in: directory)
    }

    static func hasPendingItems() -> Bool {
        RadixSharedImportKind.allCases.forEach(recoverAbandonedProcessingItems)
        return !pendingTextURLs().isEmpty || !pendingImageURLs().isEmpty
    }

    static func claimPendingItems() -> [RadixSharedImportQueueItem] {
        RadixSharedImportKind.allCases.flatMap { kind -> [RadixSharedImportQueueItem] in
            recoverAbandonedProcessingItems(for: kind)
            guard let incoming = directory(for: kind, state: .incoming),
                  let processing = directory(for: kind, state: .processing, create: true) else {
                return []
            }

            return sortedPendingURLs(in: incoming).compactMap { sourceURL in
                guard let id = itemID(from: sourceURL) else { return nil }
                let destinationURL = processing
                    .appendingPathComponent("\(id.uuidString)__\(processIdentifier)")
                    .appendingPathExtension(sourceURL.pathExtension)
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                    return RadixSharedImportQueueItem(id: id, kind: kind, fileURL: destinationURL)
                } catch {
                    return nil
                }
            }
        }
    }

    static func complete(_ item: RadixSharedImportQueueItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
    }

    static func fail(_ item: RadixSharedImportQueueItem, message: String) -> RadixSharedImportFailure {
        guard let failedDirectory = directory(for: item.kind, state: .failed, create: true) else {
            return RadixSharedImportFailure(item: item, message: message)
        }
        let destinationURL = failedDirectory
            .appendingPathComponent(item.id.uuidString)
            .appendingPathExtension(item.fileURL.pathExtension)
        try? FileManager.default.removeItem(at: destinationURL)

        let failedURL: URL
        do {
            try FileManager.default.moveItem(at: item.fileURL, to: destinationURL)
            failedURL = destinationURL
        } catch {
            failedURL = item.fileURL
        }
        if failedURL == destinationURL {
            try? message.write(to: errorURL(for: destinationURL), atomically: true, encoding: .utf8)
        }
        return RadixSharedImportFailure(
            item: RadixSharedImportQueueItem(id: item.id, kind: item.kind, fileURL: failedURL),
            message: message
        )
    }

    static func firstFailure() -> RadixSharedImportFailure? {
        for kind in RadixSharedImportKind.allCases {
            guard let failedDirectory = directory(for: kind, state: .failed) else { continue }
            let failedURLs = sortedPendingURLs(in: failedDirectory).filter {
                !$0.lastPathComponent.hasSuffix(".error.txt")
            }
            guard let fileURL = failedURLs.first, let id = itemID(from: fileURL) else { continue }
            let message = (try? String(contentsOf: errorURL(for: fileURL), encoding: .utf8))
                ?? "Radix could not import this shared \(kind == .image ? "image" : "text")."
            return RadixSharedImportFailure(
                item: RadixSharedImportQueueItem(id: id, kind: kind, fileURL: fileURL),
                message: message
            )
        }
        return nil
    }

    static func retry(_ failure: RadixSharedImportFailure) throws {
        guard let incoming = directory(for: failure.item.kind, state: .incoming, create: true) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let destinationURL = incoming
            .appendingPathComponent(failure.id.uuidString)
            .appendingPathExtension(failure.item.fileURL.pathExtension)
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: failure.item.fileURL, to: destinationURL)
        try? FileManager.default.removeItem(at: errorURL(for: failure.item.fileURL))
    }

    static func discard(_ failure: RadixSharedImportFailure) {
        try? FileManager.default.removeItem(at: failure.item.fileURL)
        try? FileManager.default.removeItem(at: errorURL(for: failure.item.fileURL))
    }

    private enum QueueState {
        case incoming
        case processing
        case failed
    }

    private static func directory(
        for kind: RadixSharedImportKind,
        state: QueueState,
        create: Bool = false
    ) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }
        let name: String
        switch (kind, state) {
        case (.image, .incoming): name = incomingDirectoryName
        case (.text, .incoming): name = incomingTextDirectoryName
        case (.image, .processing): name = processingImageDirectoryName
        case (.text, .processing): name = processingTextDirectoryName
        case (.image, .failed): name = failedImageDirectoryName
        case (.text, .failed): name = failedTextDirectoryName
        }
        let directory = container.appendingPathComponent(name, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func recoverAbandonedProcessingItems(for kind: RadixSharedImportKind) {
        guard let processing = directory(for: kind, state: .processing),
              let incoming = directory(for: kind, state: .incoming, create: true) else { return }
        for sourceURL in sortedPendingURLs(in: processing) {
            let name = sourceURL.deletingPathExtension().lastPathComponent
            let parts = name.split(separator: "__", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[1] != processIdentifier, let id = UUID(uuidString: parts[0]) else {
                continue
            }
            let destinationURL = incoming
                .appendingPathComponent(id.uuidString)
                .appendingPathExtension(sourceURL.pathExtension)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: sourceURL)
            } else {
                try? FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            }
        }
    }

    private static func itemID(from url: URL) -> UUID? {
        let name = url.deletingPathExtension().lastPathComponent
        let idText = name.split(separator: "__", maxSplits: 1).first.map(String.init) ?? name
        return UUID(uuidString: idText)
    }

    private static func errorURL(for itemURL: URL) -> URL {
        itemURL.deletingPathExtension().appendingPathExtension("error.txt")
    }

    private static func sortedPendingURLs(in directory: URL) -> [URL] {
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
