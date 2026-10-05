import Foundation
import ZIPFoundation

class IPAManager {
    static func extractIPA(at ipaURL: URL) throws -> URL {
        DebugLogger.shared.debug("Starting extraction for \(ipaURL.lastPathComponent)", category: "IPA")
        
        // Validate file exists and is accessible
        guard FileManager.default.fileExists(atPath: ipaURL.path) else {
            let errorMsg = "IPA file does not exist at path: \(ipaURL.path)"
            DebugLogger.shared.error(errorMsg, category: "IPA")
            throw IPAError.fileNotFound
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFileAtPath(ipaURL.path) else {
            let errorMsg = "IPA file is not readable: \(ipaURL.path)"
            DebugLogger.shared.error(errorMsg, category: "IPA")
            throw IPAError.fileNotReadable
        }
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Try to open archive with better error handling
        guard let archive = Archive(url: ipaURL, accessMode: .read) else {
            let errorMsg = "Archive could not be opened: \(ipaURL.lastPathComponent). The file may be corrupted or not a valid ZIP archive."
            DebugLogger.shared.error(errorMsg, category: "IPA")
            // Cleanup temp directory on failure
            try? FileManager.default.removeItem(at: tempDir)
            throw IPAError.extractionFailed
        }

        var extractedCount = 0
        for entry in archive {
            if entry.path.contains("__MACOSX") {
                DebugLogger.shared.debug("Skipping macOS metadata: \(entry.path)", category: "IPA")
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
            extractedCount += 1
        }

        DebugLogger.shared.info("IPA extracted successfully: \(extractedCount) file entries to \(tempDir.lastPathComponent)", category: "IPA")
        return tempDir
    }

    static func listFiles(in ipaURL: URL) throws -> [String] {
        DebugLogger.shared.debug("Listing files inside \(ipaURL.lastPathComponent)", category: "IPA")
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let results = listAllFilesRecursively(in: extractedDir)
        let sortedResults = results.sorted()
        DebugLogger.shared.info("Found \(sortedResults.count) files in \(ipaURL.lastPathComponent)", category: "IPA")
        return sortedResults
    }

    static func removeFile(at path: String, in ipaURL: URL) throws {
        DebugLogger.shared.debug("Attempting to remove \(path) from \(ipaURL.lastPathComponent)", category: "IPA")
        let extractedDir = try extractIPA(at: ipaURL)
        defer { cleanup(extractedDir) }

        let targetPath = extractedDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
            DebugLogger.shared.info("Removed file from extracted IPA: \(path)", category: "IPA")
        } else {
            DebugLogger.shared.warning("Target file not found during removal: \(path)", category: "IPA")
        }

        try repackageIPA(from: extractedDir, to: ipaURL)
    }

    static func repackageIPA(from directory: URL, to outputURL: URL) throws {
        DebugLogger.shared.debug("Repackaging IPA to \(outputURL.lastPathComponent)", category: "IPA")
        try? FileManager.default.removeItem(at: outputURL)

        guard let archive = Archive(url: outputURL, accessMode: .create) else {
            DebugLogger.shared.error("Failed to create archive for repackaging: \(outputURL.lastPathComponent)", category: "IPA")
            throw IPAError.repackagingFailed
        }

        var packedCount = 0
        for path in listAllFilesRecursively(in: directory) {
            let sourceURL = directory.appendingPathComponent(path)
            _ = sourceURL
            try archive.addEntry(with: path, relativeTo: directory)
            packedCount += 1
        }

        DebugLogger.shared.info("IPA repackaged successfully: \(packedCount) entries added to \(outputURL.lastPathComponent)", category: "IPA")
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
        do {
            try FileManager.default.removeItem(at: directory)
            DebugLogger.shared.debug("Temporary extraction directory cleaned up: \(directory.lastPathComponent)", category: "IPA")
        } catch {
            DebugLogger.shared.warning("Could not clean up temporary directory: \(error.localizedDescription)", category: "IPA")
        }
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
            return "Failed to extract the IPA file. It may be corrupted or not a valid ZIP archive."
        case .repackagingFailed:
            return "Failed to repackage the IPA file."
        case .fileNotFound:
            return "The IPA file does not exist."
        case .fileNotReadable:
            return "The IPA file cannot be read. Check file permissions."
        }
    }
}
