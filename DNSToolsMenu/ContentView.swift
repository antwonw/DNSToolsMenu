import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // --- NEW: Actions passed from AppDelegate ---
    var onOpenSettings: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    
    // Settings
    @AppStorage("app_mode") private var appMode: String = "Local Native"
    @AppStorage("dns_provider") private var dnsProvider: String = "System"
    @AppStorage("MX_API_KEY") private var apiKey: String = ""
    
    // State
    @State private var inputText: String = ""
    @State private var selectedCommand: MXCommand = .dns
    @State private var records: [MXRecord] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var usageString: String = "Usage: --"
    
    // Services
    let localService = LocalService()
    let apiService = APIService()
    
    var placeholderText: String {
        switch selectedCommand {
        case .dkim: return "domain:selector"
        case .blacklist: return "IP or Domain"
        default: return "domain.com"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- Top Bar ---
            VStack(spacing: 12) {
                HStack {
                    Text("DNSTools")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    
                    // Badge
                    Text(badgeText)
                        .font(.caption).monospacedDigit().bold()
                        .padding(4)
                        .foregroundStyle(.white)
                        .background(badgeColor)
                        .cornerRadius(4)
                        .help("Current Mode/Status")
                    
                    // FIX: Call the closure
                    Button(action: {
                        onOpenSettings?()
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                
                if appMode == "MXToolbox API" && apiKey.isEmpty {
                    Text("⚠️ API Key Missing in Settings")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                HStack(spacing: 8) {
                    Picker("", selection: $selectedCommand) {
                        ForEach(MXCommand.allCases) { cmd in
                            Text(cmd.rawValue.uppercased()).tag(cmd)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 85)
                    
                    TextField(placeholderText, text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await runSearch() } }
                    
                    Button(action: { Task { await runSearch() } }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(isLoading ? Color.secondary : Color.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty || isLoading)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // --- Results Area ---
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView("Running \(selectedCommand.rawValue.uppercased())...")
                            .padding(.top, 40)
                            
                    } else if hasSearched && records.isEmpty {
                         ContentUnavailableView {
                             Label("No Results", systemImage: "magnifyingglass")
                         } description: {
                             Text(appMode == "MXToolbox API" ? "API returned no data." : "Local lookup returned no data.")
                         }
                         .padding(.top, 40)
                         
                    } else if !records.isEmpty {
                        ForEach(records) { record in
                            ResultCardView(record: record)
                        }
                    } else {
                        ContentUnavailableView("Ready to Lookup", systemImage: "terminal")
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
            
            Divider()
            
            // --- Footer ---
            HStack {
                // FIX: Call the closure
                Button("History") {
                    onOpenHistory?()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 450, height: 500)
    }
    
    // --- Badge Logic ---
    var badgeText: String {
        if appMode == "Local Native" {
            if dnsProvider.contains("Cloudflare") { return "CF (1.1.1.1)" }
            if dnsProvider.contains("Google") { return "GOOG (8.8.8.8)" }
            if dnsProvider == "Custom" { return "CUSTOM" }
            return "LOCAL (SYS)"
        } else {
            return usageString
        }
    }
    
    var badgeColor: Color {
        if appMode == "Local Native" {
            return dnsProvider == "System" ? Color.gray.opacity(0.8) : Color.green.opacity(0.8)
        } else {
            return Color.blue.opacity(0.8)
        }
    }

        // --- Search Logic ---
        private func runSearch() async {
            guard !inputText.isEmpty else { return }
            
            isLoading = true
            hasSearched = false
            records = []
            
            // Determine Engine String for History
            let currentEngine: String
            if appMode == "Local Native" {
                if dnsProvider.contains("Cloudflare") { currentEngine = "Local (CF)" }
                else if dnsProvider.contains("Google") { currentEngine = "Local (Google)" }
                else if dnsProvider == "Custom" { currentEngine = "Local (Custom)" }
                else { currentEngine = "Local (System)" }
            } else {
                currentEngine = "MXToolbox API"
            }
            
            if appMode == "Local Native" {
                let results = await localService.runCommand(command: selectedCommand, argument: inputText)
                self.records = results
                // Pass engine to saveHistory
                saveHistory(raw: results.map { $0.formattedString }.joined(separator: "\n---\n"), engine: currentEngine)
            } else {
                do {
                    let rawJSON = try await apiService.performLookup(command: selectedCommand.rawValue, argument: inputText)
                    self.records = JSONParser.extractRecords(jsonString: rawJSON)
                    // Pass engine to saveHistory
                    saveHistory(raw: rawJSON, engine: currentEngine)
                    await updateApiUsage()
                } catch {
                    print("API Error: \(error)")
                }
            }
            
            isLoading = false
            hasSearched = true
        }
        
        private func saveHistory(raw: String, engine: String) {
            let item = HistoryItem(command: selectedCommand.rawValue, argument: inputText, resultRaw: raw, engine: engine)
            modelContext.insert(item)
        }
    
    private func updateApiUsage() async {
        if let usage = await apiService.getUsage() {
            let current = (usage.dnsRequests ?? 0) + (usage.networkRequests ?? 0)
            let max = (usage.dnsMax ?? 0) + (usage.networkMax ?? 0)
            usageString = max > 0 ? "Usage: \(current) / \(max)" : "Usage: \(current)"
        } else {
            usageString = "Usage: --"
        }
    }
}
