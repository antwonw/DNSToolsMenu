import SwiftUI

struct ResultCardView: View {
    let record: MXRecord
    
    let fieldConfig: [(key: String, icon: String, label: String)] = [
        ("Status", "checkmark.shield", "Status"),
        ("IP Address", "pc", "IP Address"),
        ("Hostname", "network", "Hostname"),
        ("Pref", "list.number", "Pref"),
        ("TTL", "timer", "TTL"),
        
        // HTTP Keys
        ("Status Code", "globe", "Web Status"),
        ("Server", "server.rack", "Server"),
        
        // Ping Keys
        ("Response Time", "stopwatch", "Time"),
        ("Target", "scope", "Target"),
        
        // WHOIS Keys (Correct Order)
        ("Registrar", "building.2", "Registrar"),
        ("Created", "calendar.badge.plus", "Created"),
        ("Updated", "calendar.badge.exclamationmark", "Updated"),
        ("Expires", "calendar.badge.clock", "Expires"),
        ("Name Servers", "server.rack", "Nameservers"),
        ("Domain Status", "exclamationmark.triangle", "Status"),
        
        // Generic Large Data
        ("Full Record", "text.alignleft", "Data"),
        ("Public Key", "key", "Key")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // --- Header ---
            HStack {
                Image(systemName: iconForRecord)
                    .foregroundStyle(.blue)
                Text(record.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                
                Button(action: { copyToClipboard(record.formattedString) }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy full record")
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // --- Configured Fields ---
            ForEach(fieldConfig, id: \.key) { config in
                if let val = record.data[config.key] as? String, !val.isEmpty {
                    DetailRow(icon: config.icon, label: config.label, value: val)
                }
            }
            
            // --- Catch-All ---
            ForEach(record.data.keys.sorted(), id: \.self) { key in
                if !isIgnored(key) && !isAlreadyShown(key) {
                    if let val = record.data[key] as? String, !val.isEmpty {
                        DetailRow(icon: "circle.fill", label: key, value: val)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    var iconForRecord: String {
        if record.title.contains("Ping") { return "waveform.path.ecg" }
        if record.title.contains("Web") { return "safari" }
        if record.title.contains("Whois") { return "person.text.rectangle" }
        return "globe"
    }
    
    private func isIgnored(_ key: String) -> Bool {
        return ["title", "Name"].contains(key)
    }
    
    private func isAlreadyShown(_ key: String) -> Bool {
        return fieldConfig.contains { $0.key == key }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
                .font(.caption)
                .padding(.top, 2)
            
            statusView(for: value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true) // Allows multiline text (Important for NS)
            
            Spacer()
            
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .opacity(0.5)
            }
            .buttonStyle(.plain)
            .help("Copy value")
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    func statusView(for text: String) -> some View {
        if text.contains("[GREEN]") {
            Text(text.replacingOccurrences(of: "[GREEN] ", with: "")).foregroundStyle(.green)
        } else if text.contains("[RED]") {
            Text(text.replacingOccurrences(of: "[RED] ", with: "")).foregroundStyle(.red)
        } else {
            Text(text)
        }
    }
}
