import Foundation

enum ProjectLiveDataLocator {
    static func projectRoot(fileManager: FileManager = .default) -> URL? {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectMarker = projectRoot.appendingPathComponent("Radix.xcodeproj")

        guard fileManager.fileExists(atPath: projectMarker.path) else {
            return nil
        }
        return projectRoot
    }

    static func file(named filename: String, fileManager: FileManager = .default) -> URL? {
        guard let projectRoot = projectRoot(fileManager: fileManager) else {
            return nil
        }
        let projectFile = projectRoot.appendingPathComponent(filename)
        let projectPath = projectRoot.path
        let filePath = projectFile.path

        if fileManager.fileExists(atPath: filePath) {
            guard fileManager.isReadableFile(atPath: filePath),
                  fileManager.isWritableFile(atPath: filePath) else {
                return nil
            }
            return projectFile
        }

        if fileManager.isReadableFile(atPath: projectPath),
           fileManager.isWritableFile(atPath: projectPath) {
            return projectFile
        }

        return nil
    }
}
