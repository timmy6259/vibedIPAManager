import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingImporter = false
    @State private var selectedIPA: URL?
    @State private var status = "Choose an IPA to begin."

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Tiny IPA Manager",
                systemImage: "shippingbox",
                description: Text(status)
            )
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
            switch result {
            case .success(let urls):
                selectedIPA = urls.first
                status = urls.first.map { "Loaded \($0.lastPathComponent). File editing is ready to be added." } ?? status
            case .failure(let error):
                status = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
}