import Foundation
import SwiftUI
import UIKit

struct DebugLogEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: DebugLogLevel
    let category: String
    let message: String

    init(level: DebugLogLevel, category: String, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var fullText: String {
        "[\(level.rawValue)] [\(category)] [\(formattedTimestamp)] \(message)"
    }
}

enum DebugLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    var tintColor: Color {
        switch self {
        case .debug:
            return .blue
        case .info:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    @Published private(set) var entries: [DebugLogEntry] = []
    private let maxEntries = 80

    private init() {}

    func debug(_ message: String, category: String = "App") {
        log(message, level: .debug, category: category)
    }

    func info(_ message: String, category: String = "App") {
        log(message, level: .info, category: category)
    }

    func warning(_ message: String, category: String = "App") {
        log(message, level: .warning, category: category)
    }

    func error(_ message: String, category: String = "App") {
        log(message, level: .error, category: category)
    }

    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
        }
    }

    func copyAllLogs() -> String {
        return entries.map { $0.fullText }.joined(separator: "\n")
    }

    private func log(_ message: String, level: DebugLogLevel, category: String) {
        let entry = DebugLogEntry(level: level, category: category, message: message)
        print("[\(level.rawValue)] [\(category)] \(message)")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }
}

struct DebugDockBar: View {
    @ObservedObject var logger: DebugLogger
    @State private var isExpanded = true
    @State private var copiedEntryID: UUID?
    @State private var copiedAllLogs = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Debug Dock")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { copyAllLogs() }) {
                    Label(copiedAllLogs ? "Copied" : "Copy All", systemImage: copiedAllLogs ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)

                Button(action: { isExpanded.toggle() }) {
                    Label(isExpanded ? "Hide" : "Show", systemImage: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)

                Button(action: { logger.clear() }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5).opacity(0.95))

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(logger.entries.suffix(8).reversed()), id: \.id) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(entry.level.tintColor)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("[\(entry.level.rawValue)] \(entry.category) • \(entry.formattedTimestamp)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Text(entry.message)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Button(action: {
                                    copyLog(entry)
                                }) {
                                    Image(systemName: copiedEntryID == entry.id ? "checkmark" : "doc.on.doc")
                                        .font(.caption2)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 180)
                .background(Color(.systemBackground).opacity(0.9))
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: -2)
    }

    private func copyLog(_ entry: DebugLogEntry) {
        UIPasteboard.general.string = entry.fullText
        copiedEntryID = entry.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedEntryID == entry.id {
                copiedEntryID = nil
            }
        }
    }

    private func copyAllLogs() {
        let allLogs = logger.copyAllLogs()
        UIPasteboard.general.string = allLogs
        copiedAllLogs = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedAllLogs = false
        }
    }
}
