import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingImporter = false
    @State private var selectedIPA: URL?
    @State private var ipaContents: [String] = []
    @State private var status = "Choose an IPA to begin."
    @State private var selectedFiles: Set<String> = []
    @State private var showingFileDetails = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if ipaContents.isEmpty {
                    ContentUnavailableView(
                        "Tiny IPA Manager",
                        systemImage: "shippingbox",
                        description: Text(status)
                    )
                } else {
                    List(ipaContents, id: \.self, selection: $selectedFiles) { file in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .environment(\.editMode, .constant(.active))
                    
                    HStack(spacing: 12) {
                        Button(action: { selectedFiles.removeAll() }) {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .disabled(selectedFiles.isEmpty)
                        
                        Button(role: .destructive, action: { removeSelectedFiles() }) {
                            Label("Remove", systemImage: "trash")
                        }
                        .disabled(selectedFiles.isEmpty)
                        
                        Spacer()
                        
                        Button(action: { exportModifiedIPA() }) {
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
                    Button("Import IPA") { showingImporter = true }
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.init(filenameExtension: "ipa") ?? .archive],
            allowsMultipleSelection: false
        ) { result in
            handleIPAImport(result)
        }
    }
    
    private func handleIPAImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let ipaURL = urls.first else { return }
            selectedIPA = ipaURL
            loadIPAContents(ipaURL)
        case .failure(let error):
            status = "Import failed: \(error.localizedDescription)"
        }
    }
    
    private func loadIPAContents(_ ipaURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contents = try IPAManager.listFiles(in: ipaURL)
                DispatchQueue.main.async {
                    self.ipaContents = contents
                    self.status = "Loaded \(ipaURL.lastPathComponent) (\(contents.count) files)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "Failed to load IPA: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func removeSelectedFiles() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let ipaURL = selectedIPA else { return }
                for file in selectedFiles {
                    try IPAManager.removeFile(at: file, in: ipaURL)
                }
                DispatchQueue.main.async {
                    ipaContents.removeAll { selectedFiles.contains($0) }
                    selectedFiles.removeAll()
                    status = "Removed \(selectedFiles.count) files"
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Error removing files: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportModifiedIPA() {
        status = "Export feature coming soon..."
    }
}

#Preview {
    ContentView()
}
