import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Owns the durable pointer used to publish a complete restored data set.
struct RestoreGenerationStore: @unchecked Sendable {
    enum Phase: String, Codable, Sendable {
        case staging
        case promoted
    }

    struct Entry: Codable, Equatable, Sendable {
        var version = 1
        let previousGeneration: String
        let stagedGeneration: String
        var phase: Phase
    }

    let rootURL: URL
    let fileManager: FileManager = .default

    static let shared = RestoreGenerationStore(rootURL: defaultRootURL())

    private var generationsURL: URL { rootURL.appendingPathComponent("Data Generations", isDirectory: true) }
    private var currentLinkURL: URL { rootURL.appendingPathComponent("Current Data", isDirectory: true) }
    private var journalURL: URL { rootURL.appendingPathComponent("pending-restore-generation.json") }

    var isPending: Bool { fileManager.fileExists(atPath: journalURL.path) }

    var pendingPhase: Phase? { try? readEntry().phase }

    func activeDirectoryURL() throws -> URL {
        try ensureActiveGeneration()
        let destination = try fileManager.destinationOfSymbolicLink(atPath: currentLinkURL.path)
        let url = URL(fileURLWithPath: destination, relativeTo: currentLinkURL.deletingLastPathComponent())
            .standardizedFileURL
        guard url.deletingLastPathComponent() == generationsURL.standardizedFileURL else {
            throw failure("The active Radix data location is invalid.")
        }
        return url
    }

    func activeItemURL(_ name: String) throws -> URL {
        try activeDirectoryURL().appendingPathComponent(name)
    }

    func currentItemURL(_ name: String) throws -> URL {
        try ensureActiveGeneration()
        return currentLinkURL.appendingPathComponent(name)
    }

    func globalItemURL(_ name: String) -> URL {
        rootURL.appendingPathComponent(name)
    }

    func migrateLegacyItem(at legacyURL: URL, to name: String) throws -> URL {
        let destination = try activeItemURL(name)
        guard !fileManager.fileExists(atPath: destination.path),
              fileManager.fileExists(atPath: legacyURL.path),
              legacyURL.standardizedFileURL != destination.standardizedFileURL
        else { return destination }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: legacyURL, to: destination)
        try synchronizeDirectory(destination.deletingLastPathComponent())
        return destination
    }

    @discardableResult
    func beginStaging() throws -> Entry {
        guard !isPending else { throw failure("Finish recovering the interrupted backup restore first.") }
        let previousURL = try activeDirectoryURL()
        let stagedName = UUID().uuidString.lowercased()
        let stagedURL = generationsURL.appendingPathComponent(stagedName, isDirectory: true)
        let entry = Entry(
            previousGeneration: previousURL.lastPathComponent,
            stagedGeneration: stagedName,
            phase: .staging
        )
        try writeEntry(entry)
        do {
            try cloneDirectory(from: previousURL, to: stagedURL)
            try switchCurrent(to: stagedName)
            return entry
        } catch {
            try? switchCurrent(to: entry.previousGeneration)
            try? fileManager.removeItem(at: stagedURL)
            try? fileManager.removeItem(at: journalURL)
            throw error
        }
    }

    func markPromoted() throws {
        var entry = try readEntry()
        guard entry.phase == .staging else { return }
        entry.phase = .promoted
        try writeEntry(entry)
    }

    /// Restores the only safe pointer before repositories open at launch.
    func recoverPointerBeforeOpening() throws {
        guard isPending else {
            try ensureActiveGeneration()
            return
        }
        let entry = try readEntry()
        switch entry.phase {
        case .staging:
            try switchCurrent(to: entry.previousGeneration)
            try retire(entry: entry, removing: entry.stagedGeneration)
        case .promoted:
            try requireGeneration(entry.stagedGeneration)
            try switchCurrent(to: entry.stagedGeneration)
        }
    }

    func rollBackPendingPromotion() throws {
        guard isPending else { return }
        let entry = try readEntry()
        try requireGeneration(entry.previousGeneration)
        try switchCurrent(to: entry.previousGeneration)
        try retire(entry: entry, removing: entry.stagedGeneration)
    }

    func finishPromotion() throws {
        guard isPending else { return }
        let entry = try readEntry()
        guard entry.phase == .promoted else {
            throw failure("The restored Radix data was not promoted.")
        }
        try requireGeneration(entry.stagedGeneration)
        try switchCurrent(to: entry.stagedGeneration)
        try retire(entry: entry, removing: entry.previousGeneration)
    }

    private func ensureActiveGeneration() throws {
        try fileManager.createDirectory(at: generationsURL, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: currentLinkURL.path) { return }
        let name = UUID().uuidString.lowercased()
        try fileManager.createDirectory(
            at: generationsURL.appendingPathComponent(name, isDirectory: true),
            withIntermediateDirectories: true
        )
        try switchCurrent(to: name)
    }

    private func cloneDirectory(from sourceURL: URL, to destinationURL: URL) throws {
        #if canImport(Darwin)
        let flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_CLONE)
        if copyfile(sourceURL.path, destinationURL.path, nil, flags) == 0 { return }
        let cloneError = errno
        if cloneError != ENOTSUP && cloneError != EXDEV && cloneError != EINVAL {
            throw POSIXError(POSIXErrorCode(rawValue: cloneError) ?? .EIO)
        }
        #endif
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func switchCurrent(to generation: String) throws {
        try requireGeneration(generation)
        let temporaryURL = rootURL.appendingPathComponent("current-data-\(UUID().uuidString).link")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(
            at: temporaryURL,
            withDestinationURL: generationsURL.appendingPathComponent(generation, isDirectory: true)
        )
        #if canImport(Darwin)
        guard rename(temporaryURL.path, currentLinkURL.path) == 0 else {
            let code = errno
            try? fileManager.removeItem(at: temporaryURL)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        #else
        if fileManager.fileExists(atPath: currentLinkURL.path) {
            try fileManager.removeItem(at: currentLinkURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: currentLinkURL)
        #endif
        try synchronizeDirectory(rootURL)
    }

    private func requireGeneration(_ generation: String) throws {
        let url = generationsURL.appendingPathComponent(generation, isDirectory: true).standardizedFileURL
        guard url.deletingLastPathComponent() == generationsURL.standardizedFileURL,
              fileManager.fileExists(atPath: url.path)
        else { throw failure("A backup restore data generation is missing.") }
    }

    private func writeEntry(_ entry: Entry) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(entry).write(to: journalURL, options: .atomic)
        try synchronizeFile(journalURL)
        try synchronizeDirectory(rootURL)
    }

    private func readEntry() throws -> Entry {
        let entry = try JSONDecoder().decode(Entry.self, from: Data(contentsOf: journalURL))
        guard entry.version == 1,
              !entry.previousGeneration.isEmpty,
              !entry.stagedGeneration.isEmpty,
              entry.previousGeneration != entry.stagedGeneration
        else { throw failure("The interrupted restore record is invalid.") }
        return entry
    }

    private func retire(entry: Entry, removing generation: String) throws {
        try fileManager.removeItem(at: journalURL)
        try synchronizeDirectory(rootURL)
        let removableURL = generationsURL.appendingPathComponent(generation, isDirectory: true)
        if fileManager.fileExists(atPath: removableURL.path) {
            try? fileManager.removeItem(at: removableURL)
        }
    }

    private func synchronizeFile(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private func synchronizeDirectory(_ url: URL) throws {
        #if canImport(Darwin)
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else { throw POSIXError(.EIO) }
        #endif
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "Radix.RestoreGeneration", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL.appendingPathComponent("Radix", isDirectory: true)
    }
}
