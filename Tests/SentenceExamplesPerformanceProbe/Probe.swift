import Foundation
import UIKit

private enum SentenceExamplesProbe {
    static let queryText = "的"

    static func run() -> Int32 {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard arguments.count == 3,
                  let runID = UUID(uuidString: arguments[1]),
                  let sentenceCount = Int(arguments[2]),
                  (1...100_000).contains(sentenceCount) else {
                throw failure("Usage: seed|benchmark RUN_UUID SENTENCE_COUNT")
            }

            let fixture = try Fixture(runID: runID)
            switch arguments[0] {
            case "seed":
                let elapsed = try fixture.seed(sentenceCount: sentenceCount)
                try emit([
                    "result": "seeded",
                    "sentences": sentenceCount,
                    "seed_ms": elapsed
                ])
            case "benchmark":
                let metrics = try fixture.benchmark(expectedCount: sentenceCount)
                try emit([
                    "result": "passed",
                    "sentences": sentenceCount,
                    "first_page_ms": metrics.pageMilliseconds[0],
                    "second_page_ms": metrics.pageMilliseconds[1],
                    "third_page_ms": metrics.pageMilliseconds[2],
                    "maximum_frame_gap_ms": metrics.maximumFrameGapMilliseconds
                ])
                try fixture.cleanup()
            default:
                throw failure("Unknown command")
            }
            return 0
        } catch {
            try? emit(["result": "failed", "error": error.localizedDescription])
            return 1
        }
    }

    private static func emit(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try FileHandle.standardOutput.write(contentsOf: data + Data([10]))
    }

    private static func failure(_ message: String) -> NSError {
        NSError(
            domain: "Radix.SentenceExamplesPerformanceProbe",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private struct Metrics {
        let pageMilliseconds: [Double]
        let maximumFrameGapMilliseconds: Double
    }

    private final class Fixture: @unchecked Sendable {
        let directory: URL
        let store: SentenceLibraryStore

        init(runID: UUID) throws {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RadixSentenceExamplesProbe")
                .appendingPathComponent(runID.uuidString)
            store = SentenceLibraryStore(
                databaseURL: directory.appendingPathComponent("sentences.sqlite"),
                canonicalize: { SentenceExampleRecord.upserting($0, into: []) },
                simplify: { $0 },
                matchesSearchText: { record, query in
                    query.isEmpty || record.chinese.contains(query)
                }
            )
        }

        func seed(sentenceCount: Int) throws -> Double {
            guard !FileManager.default.fileExists(atPath: directory.path) else {
                throw failure("Use a fresh run UUID")
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let records = (0..<sentenceCount).map { index in
                SentenceExampleRecord(
                    chinese: "这是第\(index)个学习的例句",
                    english: "Common-character performance fixture \(index)",
                    detectedCharacters: [queryText]
                )
            }
            let start = CFAbsoluteTimeGetCurrent()
            try store.replaceAll(records)
            return (CFAbsoluteTimeGetCurrent() - start) * 1_000
        }

        func benchmark(expectedCount: Int) throws -> Metrics {
            let heartbeat = FrameHeartbeat()
            DispatchQueue.main.sync { heartbeat.start() }
            Thread.sleep(forTimeInterval: 0.1)
            defer { DispatchQueue.main.sync { heartbeat.stop() } }

            var offset = 0
            var durations: [Double] = []
            for _ in 0..<3 {
                let start = CFAbsoluteTimeGetCurrent()
                let page = exactPage(offset: offset, limit: 24)
                durations.append((CFAbsoluteTimeGetCurrent() - start) * 1_000)
                guard page.totalCount == expectedCount,
                      page.records.count == 24,
                      let nextOffset = page.nextOffset else {
                    throw failure("Exact page was incomplete")
                }
                offset = nextOffset
            }
            Thread.sleep(forTimeInterval: 0.1)
            return Metrics(
                pageMilliseconds: durations,
                maximumFrameGapMilliseconds: heartbeat.maximumGapMilliseconds
            )
        }

        func cleanup() throws {
            try FileManager.default.removeItem(at: directory)
        }

        private func exactPage(
            offset: Int,
            limit: Int
        ) -> (records: [SentenceExampleRecord], nextOffset: Int?, totalCount: Int) {
            let resultLimit = max(1, limit)
            let queryPageSize = max(24, min(120, resultLimit * 4))
            var queryOffset = max(0, offset)
            var matches: [SentenceExampleRecord] = []
            var totalCount = 0

            while matches.count < resultLimit {
                let result = store.query(
                    SentenceExampleQuery(
                        searchText: queryText,
                        offset: queryOffset,
                        limit: queryPageSize
                    ),
                    migratingLegacy: { [] }
                )
                totalCount = result.totalCount
                guard !result.records.isEmpty else { return (matches, nil, totalCount) }

                for (index, record) in result.records.enumerated() where record.containsCharacter(queryText) {
                    matches.append(record)
                    if matches.count == resultLimit {
                        let nextOffset = queryOffset + index + 1
                        return (matches, nextOffset < result.totalCount ? nextOffset : nil, result.totalCount)
                    }
                }

                queryOffset += result.records.count
                if queryOffset >= result.totalCount { return (matches, nil, result.totalCount) }
            }
            return (matches, nil, totalCount)
        }
    }
}

private final class FrameHeartbeat: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval?
    private var maximumGap: CFTimeInterval = 0

    var maximumGapMilliseconds: Double {
        lock.withLock { maximumGap * 1_000 }
    }

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(frameDidRender(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func frameDidRender(_ link: CADisplayLink) {
        lock.withLock {
            if let previousTimestamp {
                maximumGap = max(maximumGap, link.timestamp - previousTimestamp)
            }
            previousTimestamp = link.timestamp
        }
    }
}

@main
private final class ProbeAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        DispatchQueue.global(qos: .userInitiated).async {
            exit(SentenceExamplesProbe.run())
        }
        return true
    }
}
