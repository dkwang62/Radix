import SwiftUI

extension FavouritesTab {
    func exportSentenceDatabase() {
        isRunningSentenceDatabaseTransfer = true
        sentenceExampleStatusMessage = "Preparing saved sentences..."
        Task {
            do {
                let data = try await store.exportSentenceDatabaseData()
                await MainActor.run {
                    sentenceDatabaseExportDocument = BinaryFileDocument(data: data)
                    sentenceDatabaseExportFilename = "radix_sentence_database"
                    showSentenceDatabaseExporter = true
                }
            } catch {
                await MainActor.run {
                    isRunningSentenceDatabaseTransfer = false
                    sentenceExampleStatusMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func prepareSentenceDatabaseImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else {
                sentenceExampleStatusMessage = "Import failed: no file selected."
                return
            }
            do {
                let tempURL = try copySentenceDatabaseImportToTemporaryURL(sourceURL)
                pendingSentenceDatabaseImport = PendingSentenceDatabaseImport(url: tempURL)
            } catch {
                sentenceExampleStatusMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            sentenceExampleStatusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    func copySentenceDatabaseImportToTemporaryURL(_ sourceURL: URL) throws -> URL {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("radix_sentence_database_import_\(UUID().uuidString)")
            .appendingPathExtension("db")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: tempURL)
        return tempURL
    }

    func clearPendingSentenceDatabaseImport() {
        if let url = pendingSentenceDatabaseImport?.url {
            try? FileManager.default.removeItem(at: url)
        }
        pendingSentenceDatabaseImport = nil
    }

    func importPendingSentenceDatabase(mode: RestoreMode) {
        guard let pending = pendingSentenceDatabaseImport else { return }
        pendingSentenceDatabaseImport = nil
        isRunningSentenceDatabaseTransfer = true
        sentenceExampleStatusMessage = mode == .complete
            ? "Replacing saved sentences..."
            : "Merging saved sentences..."

        Task {
            defer {
                try? FileManager.default.removeItem(at: pending.url)
            }
            do {
                let count = try await store.importSentenceDatabase(from: pending.url, mode: mode)
                await MainActor.run {
                    sentenceExampleRevision += 1
                    loadFavoriteSentences()
                    resetSentenceExamplePage()
                    clearSentenceExampleSelection()
                    refreshSentenceExampleResults()
                    isRunningSentenceDatabaseTransfer = false
                    sentenceExampleStatusMessage = mode == .complete
                        ? "Replaced saved sentences with \(count) sentence\(count == 1 ? "" : "s")."
                        : "Merged \(count) sentence\(count == 1 ? "" : "s")."
                }
            } catch {
                await MainActor.run {
                    isRunningSentenceDatabaseTransfer = false
                    sentenceExampleStatusMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func clearSentenceDatabase() {
        isRunningSentenceDatabaseTransfer = true
        sentenceExampleStatusMessage = "Clearing saved sentences..."

        Task {
            do {
                try await store.clearSentenceDatabase()
                await MainActor.run {
                    resetSentenceExamplePage()
                    stopSelectingSentenceExamples()
                    sentenceExampleSearchText = ""
                    sentenceExampleFilter = .all
                    sentenceExampleMinimumCharacterCount = 2
                    sentenceExamplePageRecords = []
                    sentenceExampleResultCount = 0
                    sentenceExampleRevision += 1
                    loadFavoriteSentences()
                    refreshSentenceExampleResults()
                    isRunningSentenceDatabaseTransfer = false
                    sentenceExampleStatusMessage = "Cleared saved sentences. A recovery copy was created first."
                }
            } catch {
                await MainActor.run {
                    isRunningSentenceDatabaseTransfer = false
                    sentenceExampleStatusMessage = "Clear failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
