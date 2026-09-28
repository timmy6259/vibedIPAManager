import Foundation
import Compression

/// Manages IPA file operations: extraction, file manipulation, and repackaging
class IPAManager {
    /// Extract IPA contents to a temporary directory
    static func extractIPA(at ipaURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // IPA files are ZIP archives
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
    
    /// List all files in the extracted IPA structure
    static func listFiles(in directory: URL) throws -> [String] {
        let fileManager = FileManager.default
        var files: [String] = []
        
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let relativePath = fileURL.relativePath
                if !relativePath.contains("__MACOSX") {
                    files.append(relativePath)
                }
            }
        }
        return files.sorted()
    }
    
    /// Replace a file in the IPA directory structure
    static func replaceFile(at path: String, in ipaDir: URL, with newFileURL: URL) throws {
        let targetPath = ipaDir.appendingPathComponent(path)
        try FileManager.default.removeItem(at: targetPath)
        try FileManager.default.copyItem(at: newFileURL, to: targetPath)
    }
    
    /// Remove a file from the IPA directory structure
    static func removeFile(at path: String, in ipaDir: URL) throws {
        let targetPath = ipaDir.appendingPathComponent(path)
        try FileManager.default.removeItem(at: targetPath)
    }
    
    /// Repackage the modified IPA directory back into an IPA file
    static func repackageIPA(from directory: URL, to outputURL: URL) throws {
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
    
    /// Clean up temporary extraction directory
    static func cleanup(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}

enum IPAError: Error {
    case extractionFailed
    case repackagingFailed
    case fileOperationFailed(String)
}