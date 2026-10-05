import Foundation
import ZIPFoundation

class IPAManager {
    static func extractIPA(at ipaURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let archive = Archive(url: ipaURL, accessMode: .read) else {
            throw IPAError.extractionFailed
        }

        for entry in archive {
            if entry.path.contains("__MACOSX") {
                continue
            }

            let destinationURL = tempDir.appendingPathComponent(entry.path)
            let parent = destinationURL.deletingLastPathComponent()

            if entry.type == .directory {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
                continue
            }

            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try archive.extract(entry, to: destinationURL)
        }

        return tempDir
    }

    static func listFiles(in ipaURL: URL) throws -> [String] {
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let results = listAllFilesRecursively(in: extractedDir)
        return results.sorted()
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

        guard let archive = Archive(url: outputURL, accessMode: .create) else {
            throw IPAError.repackagingFailed
        }

        for path in listAllFilesRecursively(in: directory) {
            let sourceURL = directory.appendingPathComponent(path)
            try archive.addEntry(with: path, relativeTo: directory)
            _ = sourceURL
        }
    }

    private static func listAllFilesRecursively(in root: URL) -> [String] {
        let fileManager = FileManager.default
        var results: [String] = []

        if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.hasDirectoryPath {
                    continue
                }

                let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
                if relativePath.isEmpty || relativePath.contains("__MACOSX") || relativePath.hasSuffix(".DS_Store") {
                    continue
                }

                results.append(relativePath)
            }
        }

        return results
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
