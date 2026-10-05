import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingImporter = false
    @State private var selectedIPA: URL?
    @State private var ipaContents: [String] = []
    @State private var status = "Choose an IPA to begin."
    @State private var selectedFiles: Set<String> = []
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
                    } else {
                        List(ipaContents, id: \.self, selection: $selectedFiles) { file in
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                Text(file)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        .environment(\.editMode, .constant(.active))

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
                                exportModifiedIPA()
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
                selectedIPA = ipaURL
                DebugLogger.shared.info("Importing IPA: \(ipaURL.lastPathComponent)", category: "Import")
                loadIPAContents(ipaURL)
            case .failure(let error):
                status = "Import failed: \(error.localizedDescription)"
                DebugLogger.shared.error("Import failed: \(error.localizedDescription)", category: "Import")
            }
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

    private func removeSelectedFiles() {
        DebugLogger.shared.debug("Removing \(selectedFiles.count) selected files", category: "IPA")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else {
                    DebugLogger.shared.warning("No IPA selected while trying to remove files", category: "IPA")
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

    private func exportModifiedIPA() {
        DebugLogger.shared.warning("Export feature is not yet implemented", category: "UI")
        status = "Export feature coming soon..."
    }
}

#Preview {
    ContentView()
}
