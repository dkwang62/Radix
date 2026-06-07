import UniformTypeIdentifiers

typealias RadixFileType = UTType

enum RadixFileTypes {
    static var json: UTType { .json }
    static var data: UTType { .data }
    static var imageImports: [UTType] { [.image] }
    static var backupImports: [UTType] { [.json, .data] }
    static var gifIdentifier: CFString { UTType.gif.identifier as CFString }

    static func isJSON(_ type: UTType) -> Bool {
        type == .json
    }
}
