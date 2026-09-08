import Darwin
import Foundation

private struct Snapshot: Codable {
    let values: [String: Data]
}

private let names = ["sentences.sqlite", "phrases.sqlite", "preferences.plist", "page.jpg"]

private func journal(at root: URL) -> RestoreRollbackJournal {
    RestoreRollbackJournal(directoryURL: root.appendingPathComponent("journal", isDirectory: true))
}

private func writeState(_ label: String, at root: URL) throws {
    for name in names {
        try Data("\(label):\(name)".utf8).write(to: root.appendingPathComponent(name), options: .atomic)
    }
}

private func snapshot(at root: URL) throws -> Data {
    let values = try Dictionary(uniqueKeysWithValues: names.map {
        ($0, try Data(contentsOf: root.appendingPathComponent($0)))
    })
    return try PropertyListEncoder().encode(Snapshot(values: values))
}

private func apply(_ data: Data, at root: URL, killAfter: Int?) throws {
    let decoded = try PropertyListDecoder().decode(Snapshot.self, from: data)
    for (index, name) in names.enumerated() {
        try decoded.values[name]!.write(to: root.appendingPathComponent(name), options: .atomic)
        if killAfter == index { killNow() }
    }
}

private func validate(_ data: Data) throws {
    let decoded = try PropertyListDecoder().decode(Snapshot.self, from: data)
    guard Set(decoded.values.keys) == Set(names) else { throw CocoaError(.fileReadCorruptFile) }
}

private func killNow() -> Never {
    _ = kill(getpid(), SIGKILL)
    while true { pause() }
}

private func verifyOriginal(at root: URL) throws {
    for name in names {
        let value = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
        guard value == "original:\(name)" else { throw CocoaError(.fileReadCorruptFile) }
    }
}

@main
private struct RestoreRollbackProbe {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else { exit(64) }
        let mode = arguments[1]
        let root = URL(fileURLWithPath: arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        switch mode {
        case "interrupt":
            let stage = Int(arguments[3])!
            try writeState("original", at: root)
            let original = try snapshot(at: root)
            try journal(at: root).begin(snapshotData: original, validate: validate)
            if stage == -1 { killNow() }
            for index in names.indices {
                try Data("incoming:\(names[index])".utf8)
                    .write(to: root.appendingPathComponent(names[index]), options: .atomic)
                if stage == index { killNow() }
            }
            exit(65)
        case "prepare-rollback":
            try writeState("original", at: root)
            try journal(at: root).begin(snapshotData: snapshot(at: root), validate: validate)
            try writeState("incoming", at: root)
        case "recover":
            let killAfter = arguments.count > 3 ? Int(arguments[3]) : nil
            let rollback = try journal(at: root).rollbackData()
            try validate(rollback)
            try apply(rollback, at: root, killAfter: killAfter)
            try journal(at: root).finish()
            try verifyOriginal(at: root)
        case "verify":
            try verifyOriginal(at: root)
            guard !journal(at: root).isPending else { exit(66) }
        default:
            exit(64)
        }
    }
}
