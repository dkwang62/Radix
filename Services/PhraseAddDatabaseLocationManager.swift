import Foundation

final class PhraseAddDatabaseLocationManager {
    private let overrideKey = "radix.phrasesAddOverridePath"
    private let overrideBookmarkKey = "radix.phrasesAddOverrideBookmark"
    private let preferences: RadixPreferences
    private var overrideURL: URL?
    private var activeSecurityScopedURL: URL?

    init(preferences: RadixPreferences = .standard) {
        self.preferences = preferences
    }

    deinit {
        stopAccessingActiveSecurityScope()
    }

    var currentDisplayPath: String {
        if let overrideURL { return overrideURL.path }
        return resolvedAddDBURL(fileManager: .default).path
    }

    var currentLocalURL: URL {
        resolvedAddDBURL(fileManager: .default)
    }

    func resolvedActiveAddDBURL(fileManager: FileManager) throws -> URL {
        let localURL = resolvedAddDBURL(fileManager: fileManager)
        if ProjectLiveDataLocator.file(named: "phrases_add.db", fileManager: fileManager)?.path == localURL.path {
            return localURL
        }
        if let overrideURL {
            try syncWorkingAddDBFromCustomSource(overrideURL, to: localURL)
            return localURL
        }
        if let bookmarkData = preferences.data(forKey: overrideBookmarkKey) {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if fileManager.fileExists(atPath: resolvedURL.path) {
                    if beginAccessingSecurityScopeIfNeeded(for: resolvedURL) {
                        overrideURL = resolvedURL
                        if isStale {
                            persistSecurityScopedBookmark(for: resolvedURL)
                        }
                        preferences.set(resolvedURL.path, forKey: overrideKey)
                        try syncWorkingAddDBFromCustomSource(resolvedURL, to: localURL)
                        return localURL
                    }
                } else {
                    preferences.removeObject(forKey: overrideBookmarkKey)
                }
            }
        }
        if let saved = preferences.string(forKey: overrideKey) {
            let url = URL(fileURLWithPath: saved)
            if fileManager.fileExists(atPath: url.path) {
                overrideURL = url
                try syncWorkingAddDBFromCustomSource(url, to: localURL)
                return localURL
            }
            preferences.removeObject(forKey: overrideKey)
            preferences.removeObject(forKey: overrideBookmarkKey)
        }
        return localURL
    }

    func resetToDefault() {
        stopAccessingActiveSecurityScope()
        overrideURL = nil
        preferences.removeObject(forKey: overrideKey)
        preferences.removeObject(forKey: overrideBookmarkKey)
    }

    func applyOverride(_ url: URL) throws -> URL {
        stopAccessingActiveSecurityScope()
        _ = beginAccessingSecurityScopeIfNeeded(for: url)
        overrideURL = url
        preferences.set(url.path, forKey: overrideKey)
        persistSecurityScopedBookmark(for: url)

        let localURL = resolvedAddDBURL(fileManager: .default)
        try syncWorkingAddDBFromCustomSource(url, to: localURL)
        return localURL
    }

    func syncWorkingAddDBToCustomSourceIfNeeded() throws {
        guard let sourceURL = overrideURL else { return }
        let localURL = resolvedAddDBURL(fileManager: .default)
        let data = try Data(contentsOf: localURL)
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeError: NSError?

        coordinator.coordinate(writingItemAt: sourceURL, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error as NSError
            }
        }

        if let writeError {
            throw writeError
        }
        if let coordinationError {
            throw coordinationError
        }
    }

    func stopAccessingActiveSecurityScope() {
        guard let activeSecurityScopedURL else { return }
        activeSecurityScopedURL.stopAccessingSecurityScopedResource()
        self.activeSecurityScopedURL = nil
    }

    private func resolvedAddDBURL(fileManager: FileManager) -> URL {
        if let projectURL = ProjectLiveDataLocator.file(named: "phrases_add.db", fileManager: fileManager) {
            return projectURL
        }
        let localDocs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return localDocs.appendingPathComponent("phrases_add.db")
    }

    private func beginAccessingSecurityScopeIfNeeded(for url: URL) -> Bool {
        if activeSecurityScopedURL?.path == url.path {
            return true
        }
        stopAccessingActiveSecurityScope()
        if url.startAccessingSecurityScopedResource() {
            activeSecurityScopedURL = url
            return true
        }
        return false
    }

    private func persistSecurityScopedBookmark(for url: URL) {
        guard let bookmarkData = try? url.bookmarkData(options: bookmarkCreationOptions, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            preferences.removeObject(forKey: overrideBookmarkKey)
            return
        }
        preferences.set(bookmarkData, forKey: overrideBookmarkKey)
    }

    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private func syncWorkingAddDBFromCustomSource(_ sourceURL: URL, to localURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copied = false
        var readError: NSError?

        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                let data = try Data(contentsOf: coordinatedURL)
                let dir = localURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                try data.write(to: localURL, options: .atomic)
                copied = true
            } catch {
                readError = error as NSError
            }
        }

        if let readError {
            throw readError
        }
        if let coordinationError {
            throw coordinationError
        }
        if !copied {
            throw NSError(domain: "Radix", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to load custom phrases file."])
        }
    }
}
