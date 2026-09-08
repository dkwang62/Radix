import Foundation
import Darwin

// Built separately from Radix: unique app container, preference suites and data.
enum DeletionProbe {
    struct Manifest: Codable {
        let pages: [UUID]
        let favoriteID: UUID
        let sharedID: UUID
        let sentenceCount: Int
    }

    static func run() -> Int32 {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard arguments.count >= 2, let id = UUID(uuidString: arguments[1]) else {
                throw error("Usage: interrupt|recover|benchmark RUN_UUID [phase|page-count]")
            }
            let fixture = try Fixture(id: id)
            switch arguments[0] {
            case "interrupt":
                guard arguments.count == 3 else { throw error("Missing interruption phase") }
                let phase = arguments[2]
                try fixture.seed(pageCount: 100)
                if phase == "before" { try fixture.stop(at: phase) }
                try fixture.journal(interruption: phase).delete(pageIDs: fixture.deletedIDs()) { stage in
                    if String(describing: stage) == phase { try fixture.stop(at: phase) }
                }
                throw error("Interruption phase was not reached")
            case "recover":
                let marker = try String(contentsOf: fixture.directory.appendingPathComponent("interruption"), encoding: .utf8)
                let journal = fixture.journal()
                guard journal.isPending == (marker != "before") else { throw error("Unexpected journal presence after SIGKILL") }
                let start = CFAbsoluteTimeGetCurrent()
                try journal.recover()
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                try fixture.verify(deleted: marker != "before")
                try journal.recover()
                try fixture.verify(deleted: marker != "before")
                try emit(["result": "passed", "phase": marker, "recovery_ms": elapsed])
                try fixture.cleanup()
            case "benchmark":
                let pageCount = arguments.count == 3 ? Int(arguments[2]) ?? 100 : 100
                guard (100...5000).contains(pageCount) else { throw error("Page count must be 100...5000") }
                try fixture.seed(pageCount: pageCount)
                var measurements: [String: Double] = [:]
                let start = CFAbsoluteTimeGetCurrent()
                var previous = start
                try fixture.journal(onReconciliation: { measurements["sqlite"] = $0 }).delete(pageIDs: fixture.deletedIDs()) { stage in
                    let now = CFAbsoluteTimeGetCurrent()
                    measurements[String(describing: stage)] = (now - previous) * 1000
                    previous = now
                }
                let total = (CFAbsoluteTimeGetCurrent() - start) * 1000
                try fixture.verify(deleted: true)
                let emptyStart = CFAbsoluteTimeGetCurrent()
                for _ in 0..<1000 { try fixture.journal().recover() }
                let emptyAverage = CFAbsoluteTimeGetCurrent() - emptyStart
                try emit(["result": "passed", "pages": pageCount, "sentences": pageCount * 10,
                          "deletion_ms": total, "stages_ms": measurements, "empty_recovery_ms": emptyAverage])
                try fixture.cleanup()
            default:
                throw error("Unknown command")
            }
            return 0
        } catch {
            try? emit(["result": "failed", "error": error.localizedDescription])
            return 1
        }
    }

    static func emit(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try FileHandle.standardOutput.write(contentsOf: data + Data([10]))
    }

    static func error(_ message: String) -> NSError {
        NSError(domain: "Radix.DeletionProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    final class Fixture {
        let directory: URL
        let appDefaults: UserDefaults
        let studyDefaults: UserDefaults
        let suite: String
        let app: RadixPreferences
        let study: RadixPreferences
        let sentences: SentenceLibraryStore

        init(id: UUID) throws {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RadixDeletionProbe").appendingPathComponent(id.uuidString)
            suite = "com.desmond.radix.deletionqa.\(id.uuidString)"
            appDefaults = UserDefaults(suiteName: suite + ".app")!
            studyDefaults = UserDefaults(suiteName: suite + ".study")!
            app = RadixPreferences(defaults: appDefaults)
            study = RadixPreferences(defaults: studyDefaults)
            sentences = SentenceLibraryStore(databaseURL: directory.appendingPathComponent("sentences.sqlite"),
                canonicalize: { SentenceExampleRecord.upserting($0, into: []) }, simplify: { $0 },
                matchesSearchText: { _, _ in true })
        }

        func seed(pageCount: Int) throws {
            guard !FileManager.default.fileExists(atPath: directory.path) else { throw error("Use a fresh run UUID") }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let now = Date()
            let pageIDs = (0..<pageCount).map { _ in UUID() }
            let text = String(repeating: "Study text. ", count: 100)
            let pages = pageIDs.enumerated().map { index, id in
                CharacterCollection(id: id, name: "Page \(index)", characters: Array(repeating: "学", count: 100),
                    createdAt: now, sourceType: .manual, isFavorite: false, reviewedOCRText: text,
                    correctedFromCollectionID: (1...2).contains(index) ? pageIDs[0] : nil)
            }
            let source: (UUID) -> SentenceExampleSourceReference = { id in
                SentenceExampleSourceReference(sourceType: .aiCleanedPage, sourceID: id.uuidString,
                    sourceTitle: "Page", sourcePageID: id, practicePackID: nil, practiceItemID: nil)
            }
            var records = (0..<(pageCount * 10)).map { index in
                SentenceExampleRecord(chinese: "学习句子 \(index)", sources: [source(pageIDs[index / 10])])
            }
            records[0].isFavorited = true
            records[1].sources.append(source(pageIDs[3]))
            try sentences.replaceAll(records)
            app.set(try JSONEncoder().encode(pages), forKey: RadixPreferenceKey.collections)
            app.set(pageIDs[2].uuidString, forKey: RadixPreferenceKey.selectedAICollection)
            app.set(pageIDs[2].uuidString, forKey: RadixPreferenceKey.conversationPracticeTopic)
            let packs = pages.prefix(4).map { page in
                ConversationPracticePack(packID: page.id.uuidString, version: "1", title: page.name,
                    description: "", language: "zh-CN", sourceType: "probe", createdFor: "QA",
                    sourceLink: .savedPage(id: page.id, title: page.name, createdAt: now), entries: [])
            }
            ConversationPracticeStore(preferences: study).importedPacks = packs
            let artifacts = PageStudyArtifactStore(preferences: study)
            artifacts.cleanedPages = pages.map {
                AICleanedPageRecord(sourcePageID: $0.id, sourceTitle: $0.name, cleanedTitle: $0.name,
                    cleanedChineseText: text, sentences: [], createdAt: now)
            }
            artifacts.phraseExtractions = pages.map {
                PagePhraseExtractionRecord(sourcePageID: $0.id, sourceTitle: $0.name,
                    phraseWords: ["学习"], extractedAt: now)
            }
            study.set(Data([7]), forKey: RadixPreferenceKey.conversationPracticeProgress)
            study.set(Data([8]), forKey: "globalNotes")
            for id in pageIDs.prefix(4) {
                try Data(repeating: 42, count: 2 * 1024 * 1024).write(to: imageURL(id), options: .atomic)
            }
            let manifest = Manifest(pages: pageIDs, favoriteID: records[0].id,
                sharedID: records[1].id, sentenceCount: records.count)
            try JSONEncoder().encode(manifest).write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
            try app.flushPageDeletion()
            try study.flushPageDeletion()
        }

        func manifest() throws -> Manifest {
            try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        }
        func deletedIDs() throws -> Set<UUID> { Set(try manifest().pages.prefix(3)) }
        func imageURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id).jpg") }

        func journal(interruption: String? = nil, onReconciliation: ((Double) -> Void)? = nil) -> PageDeletionJournal {
            var removedImages = 0
            return PageDeletionJournal(url: directory.appendingPathComponent("journal.json"), preferences: app,
                studyPreferences: study,
                reconcileSentences: {
                    let start = CFAbsoluteTimeGetCurrent()
                    _ = try self.sentences.reconcileSources(removingPageIDs: $0, migratingLegacy: { [] })
                    onReconciliation?((CFAbsoluteTimeGetCurrent() - start) * 1000)
                },
                flushPreferences: {
                    try self.app.flushPageDeletion()
                    if interruption == "first-preference-store" { try self.stop(at: "first-preference-store") }
                    try self.study.flushPageDeletion()
                }, removeImage: { id in
                    let url = self.imageURL(id)
                    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                    removedImages += 1
                    if interruption == "first-image", removedImages == 1 { try self.stop(at: "first-image") }
                })
        }

        func stop(at phase: String) throws {
            let url = directory.appendingPathComponent("interruption")
            try Data(phase.utf8).write(to: url, options: .atomic)
            let handle = try FileHandle(forWritingTo: url)
            try handle.synchronize()
            try handle.close()
            try emit(["result": "interrupting", "phase": phase])
            kill(getpid(), SIGKILL)
            _exit(99)
        }

        func verify(deleted: Bool) throws {
            let manifest = try manifest()
            let pages = try JSONDecoder().decode([CharacterCollection].self, from: app.data(forKey: RadixPreferenceKey.collections)!)
            let retained = deleted ? Array(manifest.pages.dropFirst(3)) : manifest.pages
            guard pages.map(\.id) == retained else { throw error("Page identities changed unexpectedly") }
            let artifacts = PageStudyArtifactStore(preferences: study)
            guard Set(artifacts.cleanedPages.map(\.sourcePageID)) == Set(retained),
                  Set(artifacts.phraseExtractions.map(\.sourcePageID)) == Set(retained) else { throw error("Artifact mismatch") }
            let packs = ConversationPracticeStore(preferences: study).importedPacks
            guard Set(packs.map(\.packID)) == Set((deleted ? [manifest.pages[3]] : Array(manifest.pages.prefix(4))).map(\.uuidString)),
                  study.data(forKey: RadixPreferenceKey.conversationPracticeProgress) == Data([7]),
                  study.data(forKey: "globalNotes") == Data([8]) else { throw error("Independent learning data changed") }
            let records = sentences.fetchAll(migratingLegacy: { [] })
            guard records.count == manifest.sentenceCount - (deleted ? 28 : 0),
                  let favorite = records.first(where: { $0.id == manifest.favoriteID }), favorite.isFavorited,
                  let shared = records.first(where: { $0.id == manifest.sharedID }) else { throw error("Sentence retention failed") }
            if deleted {
                let removed = Set(manifest.pages.prefix(3))
                guard favorite.sources.isEmpty, shared.sources.map(\.sourcePageID) == [manifest.pages[3]],
                      records.allSatisfy({ $0.sources.allSatisfy { $0.sourcePageID.map { !removed.contains($0) } ?? true } }),
                      app.string(forKey: RadixPreferenceKey.selectedAICollection) == nil,
                      app.string(forKey: RadixPreferenceKey.conversationPracticeTopic) == ConversationPracticeTopic.generalGreetings.id
                else { throw error("Stale provenance or selected page/practice") }
            }
            for id in manifest.pages.prefix(4) {
                let expected = !deleted || id == manifest.pages[3]
                guard FileManager.default.fileExists(atPath: imageURL(id).path) == expected else { throw error("Image mismatch") }
            }
        }

        func cleanup() throws {
            appDefaults.removePersistentDomain(forName: suite + ".app")
            studyDefaults.removePersistentDomain(forName: suite + ".study")
            try app.flushPageDeletion()
            try study.flushPageDeletion()
            try FileManager.default.removeItem(at: directory)
        }
    }
}

#if canImport(UIKit)
import UIKit

@main
final class ProbeAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        DispatchQueue.global(qos: .userInitiated).async { exit(DeletionProbe.run()) }
        return true
    }
}
#else
@main
enum ProbeCLI {
    static func main() { exit(DeletionProbe.run()) }
}
#endif
