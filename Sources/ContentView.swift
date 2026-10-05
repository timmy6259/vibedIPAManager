import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingImporter = false
    @State private var showingFileReplacer = false
    @State private var showingFileAdder = false
    @State private var showingExporter = false
    @State private var selectedIPA: URL?
    @State private var ipaContents: [String] = []
    @State private var status = "Choose an IPA to begin."
    @State private var selectedFiles: Set<String> = []
    @State private var copiedFile: String?
    @State private var contextMenuFile: String?
    @State private var exportFileName = "modified.ipa"
    @StateObject private var debugLogger = DebugLogger.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack {
                    if ipaContents.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 52))
                                .foregroundColor(.secondary)

                            Text("Tiny IPA Manager")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(status)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onLongPressGesture {
                            // Long press on empty area to show paste/add options
                            showContextMenuForBlankArea()
                        }
                    } else {
                        List(ipaContents, id: \.self) { file in
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                Text(file)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button(action: {
                                    shareFile(file)
                                }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }

                                Button(action: {
                                    contextMenuFile = file
                                    showingFileReplacer = true
                                }) {
                                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                }

                                Button(action: {
                                    removeFile(file)
                                }) {
                                    Label("Remove", systemImage: "trash")
                                }

                                Button(action: {
                                    copiedFile = file
                                    DebugLogger.shared.info("Copied file to clipboard: \(file)", category: "UI")
                                    status = "Copied: \(file)"
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                selectedFiles.removeAll()
                                DebugLogger.shared.debug("Cleared selected file list", category: "UI")
                            }) {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .disabled(selectedFiles.isEmpty)

                            Button(role: .destructive, action: {
                                removeSelectedFiles()
                            }) {
                                Label("Remove", systemImage: "trash")
                            }
                            .disabled(selectedFiles.isEmpty)

                            Spacer()

                            Button(action: {
                                showingExporter = true
                            }) {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                    }
                }
                .navigationTitle("vibedIPAManager")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Import IPA") {
                            showingImporter = true
                            DebugLogger.shared.debug("Import IPA button tapped", category: "UI")
                        }
                    }
                }

                DebugDockBar(logger: debugLogger)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.init(filenameExtension: "ipa") ?? .archive],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let ipaURL = urls.first else { return }

                guard ipaURL.startAccessingSecurityScopedResource() else {
                    status = "Failed to access the selected IPA file."
                    DebugLogger.shared.error("Unable to access the imported IPA file securely.", category: "Import")
                    return
                }

                selectedIPA = ipaURL
                DebugLogger.shared.info("Importing IPA: \(ipaURL.lastPathComponent)", category: "Import")
                loadIPAContents(ipaURL)
            case .failure(let error):
                status = "Import failed: \(error.localizedDescription)"
                DebugLogger.shared.error("Import failed: \(error.localizedDescription)", category: "Import")
            }
        }
        .fileImporter(
            isPresented: $showingFileReplacer,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            if let file = contextMenuFile {
                switch result {
                case .success(let urls):
                    guard let fileURL = urls.first else { return }
                    replaceFile(file, with: fileURL)
                case .failure(let error):
                    status = "Replace failed: \(error.localizedDescription)"
                    DebugLogger.shared.error("Replace failed: \(error.localizedDescription)", category: "IPA")
                }
            }
            contextMenuFile = nil
        }
        .fileImporter(
            isPresented: $showingFileAdder,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let fileURL = urls.first else { return }
                showAddFileDialog(fileURL)
            case .failure(let error):
                status = "Add file failed: \(error.localizedDescription)"
                DebugLogger.shared.error("Add file failed: \(error.localizedDescription)", category: "IPA")
            }
        }
        .sheet(isPresented: $showingExporter) {
            ExportSheet(
                isPresented: $showingExporter,
                selectedIPA: selectedIPA,
                fileName: $exportFileName,
                onExport: exportModifiedIPA
            )
        }
    }

    private func loadIPAContents(_ ipaURL: URL) {
        DebugLogger.shared.debug("Starting IPA listing for \(ipaURL.lastPathComponent)", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contents = try IPAManager.listFiles(in: ipaURL)
                DispatchQueue.main.async {
                    self.ipaContents = contents
                    self.status = "Loaded \(ipaURL.lastPathComponent) (\(contents.count) files)"
                    DebugLogger.shared.info("Loaded \(contents.count) files from \(ipaURL.lastPathComponent)", category: "IPA")
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "Failed to load IPA: \(error.localizedDescription)"
                    DebugLogger.shared.error("Failed to load IPA: \(error.localizedDescription)", category: "IPA")
                }
            }
        }
    }

    private func removeFile(_ file: String) {
        DebugLogger.shared.debug("Removing file: \(file)", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else {
                    DebugLogger.shared.warning("No IPA selected", category: "IPA")
                    return
                }

                try IPAManager.removeFile(at: file, in: ipaURL)

                DispatchQueue.main.async {
                    ipaContents.removeAll { $0 == file }
                    status = "Removed: \(file)"
                    DebugLogger.shared.info("Successfully removed file: \(file)", category: "IPA")
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Error removing file: \(error.localizedDescription)"
                    DebugLogger.shared.error("Error removing file: \(error.localizedDescription)", category: "IPA")
                }
            }
        }
    }

    private func removeSelectedFiles() {
        DebugLogger.shared.debug("Removing \(selectedFiles.count) selected files", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else {
                    DebugLogger.shared.warning("No IPA selected", category: "IPA")
                    return
                }

                for file in selectedFiles {
                    DebugLogger.shared.debug("Removing \(file) from IPA", category: "IPA")
                    try IPAManager.removeFile(at: file, in: ipaURL)
                }

                DispatchQueue.main.async {
                    ipaContents.removeAll { selectedFiles.contains($0) }
                    selectedFiles.removeAll()
                    status = "Removed selected files"
                    DebugLogger.shared.info("Successfully removed selected files", category: "IPA")
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Error removing files: \(error.localizedDescription)"
                    DebugLogger.shared.error("Error removing files: \(error.localizedDescription)", category: "IPA")
                }
            }
        }
    }

    private func replaceFile(_ file: String, with fileURL: URL) {
        DebugLogger.shared.debug("Replacing file: \(file)", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else {
                    DebugLogger.shared.warning("No IPA selected", category: "IPA")
                    return
                }

                try IPAManager.replaceFile(at: file, in: ipaURL, with: fileURL)

                DispatchQueue.main.async {
                    status = "Replaced: \(file)"
                    DebugLogger.shared.info("Successfully replaced file: \(file)", category: "IPA")
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Error replacing file: \(error.localizedDescription)"
                    DebugLogger.shared.error("Error replacing file: \(error.localizedDescription)", category: "IPA")
                }
            }
        }
    }

    private func showAddFileDialog(_ fileURL: URL) {
        let alert = UIAlertController(
            title: "Add File",
            message: "Enter the path where this file should be added in the IPA:",
            preferredStyle: .alert
        )

        alert.addTextField { field in
            field.text = fileURL.lastPathComponent
            field.placeholder = "path/to/file.txt"
        }

        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            if let path = alert.textFields?.first?.text, !path.isEmpty {
                addFile(fileURL, at: path)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    private func addFile(_ fileURL: URL, at path: String) {
        DebugLogger.shared.debug("Adding file at path: \(path)", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else {
                    DebugLogger.shared.warning("No IPA selected", category: "IPA")
                    return
                }

                try IPAManager.addFile(fileURL, at: path, in: ipaURL)

                DispatchQueue.main.async {
                    if !ipaContents.contains(path) {
                        ipaContents.append(path)
                        ipaContents.sort()
                    }
                    status = "Added: \(path)"
                    DebugLogger.shared.info("Successfully added file at: \(path)", category: "IPA")
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Error adding file: \(error.localizedDescription)"
                    DebugLogger.shared.error("Error adding file: \(error.localizedDescription)", category: "IPA")
                }
            }
        }
    }

    private func shareFile(_ file: String) {
        DebugLogger.shared.debug("Preparing to share file: \(file)", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else {
                    DebugLogger.shared.warning("No IPA selected", category: "IPA")
                    return
                }

                let extractedDir = try IPAManager.extractIPA(at: ipaURL)
                let fileURL = extractedDir.appendingPathComponent(file)

                DispatchQueue.main.async {
                    let activityController = UIActivityViewController(
                        activityItems: [fileURL],
                        applicationActivities: nil
                    )

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(activityController, animated: true)
                    }

                    DebugLogger.shared.info("Sharing file: \(file)", category: "IPA")
                }

                // Cleanup after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    IPAManager.cleanup(extractedDir)
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Error sharing file: \(error.localizedDescription)"
                    DebugLogger.shared.error("Error sharing file: \(error.localizedDescription)", category: "IPA")
                }
            }
        }
    }

    private func exportModifiedIPA() {
        DebugLogger.shared.debug("Exporting modified IPA", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else {
                    DebugLogger.shared.warning("No IPA selected", category: "IPA")
                    return
                }

                let fileName = exportFileName.isEmpty ? "modified.ipa" : exportFileName
                let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

                try IPAManager.exportIPA(from: ipaURL, to: exportURL)

                DispatchQueue.main.async {
                    // Present share sheet for export
                    let activityController = UIActivityViewController(
                        activityItems: [exportURL],
                        applicationActivities: nil
                    )

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(activityController, animated: true)
                    }

                    status = "Exported: \(fileName)"
                    DebugLogger.shared.info("Successfully exported IPA: \(fileName)", category: "IPA")
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Export failed: \(error.localizedDescription)"
                    DebugLogger.shared.error("Export failed: \(error.localizedDescription)", category: "IPA")
                }
            }
        }
    }

    private func showContextMenuForBlankArea() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if copiedFile != nil {
            alert.addAction(UIAlertAction(title: "Paste", style: .default) { _ in
                if let copied = copiedFile {
                    addFile(URL(fileURLWithPath: copied), at: copied)
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Add File", style: .default) { _ in
            showingFileAdder = true
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

#Preview {
    ContentView()
}
