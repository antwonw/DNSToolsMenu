import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryItem.date, order: .reverse) private var history: [HistoryItem]
    
    @State private var searchText = ""
    @State private var selection: Set<HistoryItem.ID> = []
    
    // Filter logic for search bar
    var filteredHistory: [HistoryItem] {
        if searchText.isEmpty { return history }
        return history.filter {
            $0.argument.localizedCaseInsensitiveContains(searchText) ||
            $0.command.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
                Table(filteredHistory, selection: $selection) {
                    TableColumn("Date") { item in
                        Text(item.date, format: .dateTime.month().day().hour().minute())
                    }
                    .width(min: 100, max: 150)
                    
                    // NEW COLUMN
                    TableColumn("Method") { item in
                        Text(item.engine) // Displays "Local (System)" or "MX API"
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(100)
                    
                    TableColumn("Command") { item in
                        Text(item.command.uppercased())
                            .font(.caption)
                            .padding(4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .width(80)
                    
                    TableColumn("Input", value: \.argument)
                    
                    TableColumn("Result Preview") { item in
                        Text(item.resultRaw.prefix(60).replacingOccurrences(of: "\n", with: " "))
                            .foregroundStyle(.secondary)
                    }
                }
        .searchable(text: $searchText) // Enables the search bar
        .toolbar {
            // Copy Button
            ToolbarItem(placement: .automatic) {
                Button(action: copySelection) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(selection.isEmpty)
                .help("Copy selected results")
            }
            
            // Export Button
            ToolbarItem(placement: .automatic) {
                Button(action: exportCSV) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .help("Export all history to CSV")
            }
            
            // Delete Button
            ToolbarItem(placement: .automatic) {
                Button(action: deleteSelected) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selection.isEmpty)
            }
            
            // Clear All Button
            ToolbarItem(placement: .automatic) {
                Button("Clear All") {
                    try? modelContext.delete(model: HistoryItem.self)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    // --- Actions ---
    
    private func copySelection() {
        // Find selected items
        let selectedItems = history.filter { selection.contains($0.id) }
        
        // Create a string representation
        let textToCopy = selectedItems.map { item in
            "\(item.command.uppercased()) \(item.argument):\n\(item.resultRaw)"
        }.joined(separator: "\n-----------------\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
    }
    
    private func deleteSelected() {
        for item in history {
            if selection.contains(item.id) {
                modelContext.delete(item)
            }
        }
        selection.removeAll()
    }
    
    private func exportCSV() {
        // Simple CSV Generator
        let csvHeader = "Date,Command,Argument,Result\n"
        let csvRows = history.map { item in
            let cleanResult = item.resultRaw.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " ")
            return "\(item.date.formatted()),\(item.command),\(item.argument),\"\(cleanResult)\""
        }.joined(separator: "\n")
        
        let csvString = csvHeader + csvRows
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "MXHistory.csv"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? csvString.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
