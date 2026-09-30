import Foundation

class IPAManager {
    static func extractIPA(at ipaURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", ipaURL.path, "-d", tempDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw IPAError.extractionFailed
        }

        return tempDir
    }

    static func listFiles(in ipaURL: URL) throws -> [String] {
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let fileManager = FileManager.default
        var files: [String] = []

        if let enumerator = fileManager.enumerator(at: extractedDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let relativePath = fileURL.path.replacingOccurrences(of: extractedDir.path + "/", with: "")
                if !relativePath.isEmpty,
                   !relativePath.contains("__MACOSX"),
                   !relativePath.hasSuffix(".DS_Store") {
                    files.append(relativePath)
                }
            }
        }

        return files.sorted()
    }

    static func removeFile(at path: String, in ipaURL: URL) throws {
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let targetPath = extractedDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }

        try repackageIPA(from: extractedDir, to: ipaURL)
    }

    static func repackageIPA(from directory: URL, to outputURL: URL) throws {
        try? FileManager.default.removeItem(at: outputURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", outputURL.path, "."]
        process.currentDirectoryURL = directory
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw IPAError.repackagingFailed
        }
    }

    static func cleanup(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}

enum IPAError: Error, LocalizedError {
    case extractionFailed
    case repackagingFailed

    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "Failed to extract the IPA file."
        case .repackagingFailed:
            return "Failed to repackage the IPA file."
        }
    }
}
