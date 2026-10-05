import Foundation
import ZIPFoundation

final class IPAManager {
    static func extractIPA(at ipaURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let archive = Archive(url: ipaURL, accessMode: .read) else {
            try? FileManager.default.removeItem(at: tempDir)
            throw IPAError.extractionFailed
        }

        for entry in archive {
            if entry.path.contains("__MACOSX") || entry.path.contains(".DS_Store") {
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
        return listAllFilesRecursively(in: extractedDir).sorted()
    }

    static func listFiles(in directory: URL) throws -> [String] {
        listAllFilesRecursively(in: directory).sorted()
    }

    static func replaceFile(at path: String, in ipaURL: URL, with newFileURL: URL) throws {
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let destination = extractedDir.appendingPathComponent(path)
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: newFileURL, to: destination)
        try repackageIPA(from: extractedDir, to: ipaURL)
    }

    static func addFile(_ fileURL: URL, at relativePath: String, in ipaURL: URL) throws {
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let destination = extractedDir.appendingPathComponent(relativePath)
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: fileURL, to: destination)
        try repackageIPA(from: extractedDir, to: ipaURL)
    }

    static func removeFile(at path: String, in ipaURL: URL) throws {
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let target = extractedDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }

        try repackageIPA(from: extractedDir, to: ipaURL)
    }

    static func exportIPA(from ipaURL: URL, to outputURL: URL) throws {
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        try? FileManager.default.removeItem(at: outputURL)
        try repackageIPA(from: extractedDir, to: outputURL)
    }

    static func repackageIPA(from directory: URL, to outputURL: URL) throws {
        try? FileManager.default.removeItem(at: outputURL)

        guard let archive = Archive(url: outputURL, accessMode: .create) else {
            throw IPAError.repackagingFailed
        }

        for item in listAllFilesRecursively(in: directory) {
            let sourceURL = directory.appendingPathComponent(item)
            do {
                try archive.addEntry(with: item, relativeTo: directory)
                _ = sourceURL
            } catch {
                throw IPAError.repackagingFailed
            }
        }
    }

    static func cleanup(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func listAllFilesRecursively(in root: URL) -> [String] {
        let fileManager = FileManager.default
        var results: [String] = []

        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return results
        }

        for case let url as URL in enumerator {
            if url.hasDirectoryPath {
                continue
            }

            var relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            if relativePath.isEmpty || relativePath.contains("__MACOSX") || relativePath.hasSuffix(".DS_Store") {
                continue
            }
            if relativePath.hasPrefix("/") {
                relativePath.removeFirst()
            }
            results.append(relativePath)
        }

        return results
    }
}

enum IPAError: Error, LocalizedError {
    case extractionFailed
    case repackagingFailed
    case fileNotFound
    case fileNotReadable

    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "Failed to extract the IPA file."
        case .repackagingFailed:
            return "Failed to repackage the IPA file."
        case .fileNotFound:
            return "The IPA file does not exist."
        case .fileNotReadable:
            return "The IPA file cannot be read."
        }
    }
}
