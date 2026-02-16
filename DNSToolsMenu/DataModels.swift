import SwiftUI
import SwiftData

// MARK: - History Item (Updated)
@Model
class HistoryItem {
    var date: Date
    var command: String
    var argument: String
    var resultRaw: String
    var engine: String // NEW: Stores "Local (System)", "MX API", etc.
    
    init(command: String, argument: String, resultRaw: String, engine: String) {
        self.date = Date()
        self.command = command
        self.argument = argument
        self.resultRaw = resultRaw
        self.engine = engine
    }
}

// MARK: - API Usage
struct APIUsage: Codable {
    var dnsRequests: Int?
    var dnsMax: Int?
    var networkRequests: Int?
    var networkMax: Int?
    
    enum CodingKeys: String, CodingKey {
        case dnsRequests = "DnsRequests"
        case dnsMax = "DnsMax"
        case networkRequests = "NetworkRequests"
        case networkMax = "NetworkMax"
    }
}

// MARK: - Commands (Merged)
enum MXCommand: String, CaseIterable, Identifiable {
    // Tier 1: Core
    case dns, a, mx, txt, cname
    
    // Tier 2: Security
    case spf, dkim, dmarc
    
    // Tier 3: Infra
    case ns, soa, ptr, aaaa
    
    // Tier 4: Network (Hybrid)
    case ping       // Local: ping command, API: ping endpoint
    case trace      // Local: traceroute, API: trace endpoint
    case whois      // Local: whois command, API: (No direct equivalent, falls back)
    case blacklist  // API: blacklist check, Local: (Not supported, returns empty)
    
    // Tier 5: Web
    case http, https
    
    var id: String { self.rawValue }
}

// MARK: - Smart Record Parser
struct MXRecord: Identifiable {
    let id = UUID()
    let data: [String: Any]
    
    var title: String {
        if let name = data["Name"] as? String { return name }
        if let host = data["Hostname"] as? String { return host }
        if let ip = data["IP Address"] as? String { return ip }
        if let domain = data["Domain"] as? String { return domain }
        if let domainName = data["Domain Name"] as? String { return domainName }
        
        // FIX: Changed "if let msg =" to just checking if not nil
        if data["Message"] != nil { return "Notice" }
        
        return "Result"
    }
    
    var formattedString: String {
        var output = "\(title)\n"
        for (key, value) in data.sorted(by: { $0.key < $1.key }) {
            output += "\(key): \(value)\n"
        }
        return output
    }
    
    func cleanValue(for key: String) -> String {
        guard let raw = data[key] else { return "" }
        return "\(raw)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - JSON Parser (For API Mode)
struct JSONParser {
    static func extractRecords(jsonString: String) -> [MXRecord] {
        guard let data = jsonString.data(using: .utf8) else { return [] }
        var allRecords: [MXRecord] = []
        
        do {
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let info = root["Information"] as? [[String: Any]] {
                     allRecords.append(contentsOf: info.map { MXRecord(data: $0) })
                }
                if let passed = root["Passed"] as? [[String: Any]] {
                     allRecords.append(contentsOf: passed.map { MXRecord(data: $0) })
                }
                if let failed = root["Failed"] as? [[String: Any]] {
                     allRecords.append(contentsOf: failed.map { MXRecord(data: $0) })
                }
                
                if allRecords.isEmpty, let msg = root["Message"] as? String {
                    allRecords.append(MXRecord(data: ["Name": "Notice", "Message": msg]))
                }
            }
        } catch { print("JSON Parse Error: \(error)") }
        return allRecords
    }
    
    static func humanReadable(jsonString: String) -> String {
        return jsonString
    }
}
