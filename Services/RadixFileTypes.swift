import UniformTypeIdentifiers

typealias RadixFileType = UTType

enum RadixFileTypes {
    static var json: UTType { .json }
    static var data: UTType { .data }
    static var database: UTType { UTType(filenameExtension: "db") ?? .data }
    static var sqlite: UTType { UTType(filenameExtension: "sqlite") ?? database }
    static var imageImports: [UTType] { [.image] }
    static var backupImports: [UTType] { [.json, .zip, .data] }
    static var sentenceDatabaseImports: [UTType] { [database, sqlite, .data] }
    static var gifIdentifier: CFString { UTType.gif.identifier as CFString }

    static func isJSON(_ type: UTType) -> Bool {
        type == .json
    }
}
