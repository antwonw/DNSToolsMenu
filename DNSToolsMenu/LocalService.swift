import Foundation

class LocalService {
    
    func runCommand(command: MXCommand, argument: String) async -> [MXRecord] {
        let cleanArg = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanArg.isEmpty { return [] }
        
        switch command {
        case .a:     return await runDig(type: "A", domain: cleanArg)
        case .aaaa:  return await runDig(type: "AAAA", domain: cleanArg)
        case .mx:    return await runDig(type: "MX", domain: cleanArg)
        case .txt:   return await runDig(type: "TXT", domain: cleanArg)
        case .cname: return await runDig(type: "CNAME", domain: cleanArg)
        case .ns:    return await runDig(type: "NS", domain: cleanArg)
        case .soa:   return await runDig(type: "SOA", domain: cleanArg)
        case .ptr:   return await runDig(type: "PTR", domain: cleanArg)
            
        case .spf:   return await runSPF(domain: cleanArg)
        case .dmarc: return await runDig(type: "TXT", domain: "_dmarc.\(cleanArg)")
        case .dkim:  return await runDKIM(input: cleanArg)
            
        case .ping:  return await runPing(host: cleanArg)
        case .trace: return await runTrace(host: cleanArg)
        case .whois: return await runWhois(domain: cleanArg)
            
        case .http, .https: return await runCurl(url: cleanArg, secure: command == .https)
            
        case .dns:
            let a = await runDig(type: "A", domain: cleanArg)
            let mx = await runDig(type: "MX", domain: cleanArg)
            let ns = await runDig(type: "NS", domain: cleanArg)
            return a + mx + ns
            
        case .blacklist:
            return [MXRecord(data: [
                "Name": "Notice",
                "title": "Blacklist Check",
                "Message": "Blacklist checks require the MXToolbox API.\nPlease switch to 'MXToolbox API' mode in Settings.",
                "Status": "Info"
            ])]
            
        // REMOVED 'default' case because we handled all cases above.
        }
    }
    
    // --- Helper for DNS Resolver ---
    private func getDNSServerArg() -> String {
        let provider = UserDefaults.standard.string(forKey: "dns_provider") ?? "System"
        
        if provider.contains("Cloudflare") {
            return "@1.1.1.1"
        } else if provider.contains("Google") {
            return "@8.8.8.8"
        } else if provider == "Custom" {
            let customIP = UserDefaults.standard.string(forKey: "custom_dns_ip") ?? ""
            return customIP.isEmpty ? "" : "@\(customIP)"
        }
        return ""
    }

    // --- DIG RUNNER ---
    private func runDig(type: String, domain: String) async -> [MXRecord] {
        let serverArg = getDNSServerArg()
        let output = shell("dig \(serverArg) \(domain) \(type) +noall +answer")
        return parseDigOutput(output)
    }
    
    private func runSPF(domain: String) async -> [MXRecord] {
        let output = shell("dig \(domain) TXT +noall +answer")
        let records = parseDigOutput(output)
        return records.filter { ($0.data["Full Record"] as? String)?.contains("v=spf") ?? false }
    }
    
    private func runDKIM(input: String) async -> [MXRecord] {
        let parts = input.split(separator: ":")
        guard parts.count == 2 else {
            return [MXRecord(data: ["Name": "Error", "Message": "Format: domain:selector", "Status": "Fail"])]
        }
        let domain = parts[0]
        let selector = parts[1]
        let lookup = "\(selector)._domainkey.\(domain)"
        
        // FIX: Changed 'var' to 'let' as requested earlier
        let records = await runDig(type: "TXT", domain: lookup)
        
        if records.isEmpty {
            return [MXRecord(data: ["Name": "Notice", "Message": "No DKIM record found at \(lookup)", "Status": "Empty"])]
        }
        return records
    }
    
    private func parseDigOutput(_ output: String) -> [MXRecord] {
        var records: [MXRecord] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines where !line.isEmpty && !line.starts(with: ";") {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if parts.count >= 5 {
                var data: [String: Any] = [:]
                data["Name"] = parts[0]
                data["TTL"] = parts[1]
                data["Type"] = parts[3]
                let valueRaw = parts[4...].joined(separator: " ").replacingOccurrences(of: "\"", with: "")
                data["Full Record"] = valueRaw
                
                if parts[3] == "MX" && parts.count >= 6 {
                    data["Pref"] = parts[4]
                    data["Hostname"] = parts[5]
                    data["title"] = parts[5]
                } else if parts[3] == "A" || parts[3] == "AAAA" {
                    data["IP Address"] = valueRaw
                    data["title"] = valueRaw
                } else {
                    data["Hostname"] = valueRaw
                    data["title"] = valueRaw
                }
                records.append(MXRecord(data: data))
            }
        }
        return records
    }
    
    // --- WHOIS RUNNER (FINAL) ---
    private func runWhois(domain: String) async -> [MXRecord] {
        let output = shell("whois \(domain)")
        
        var cleanOutput = output
        let splitKey = "Domain Name:"
        let components = output.components(separatedBy: splitKey)
        if components.count > 1, let lastChunk = components.last {
            cleanOutput = splitKey + lastChunk
        }
        
        var data: [String: Any] = [
            "Name": "Whois Data",
            "title": "Whois: \(domain)",
            "Full Record": cleanOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        let lines = cleanOutput.components(separatedBy: .newlines)
        var nameServers: [String] = []
        
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            
            if parts.count == 2 {
                let key = parts[0].lowercased()
                let val = parts[1]
                
                if (key == "registrar" || key == "sponsoring registrar") && !key.contains("abuse") && !key.contains("email") {
                    data["Registrar"] = val
                }
                if key.contains("creation date") || key == "created" {
                    data["Created"] = val
                }
                if key.contains("registry expiry date") || key.contains("expiry date") || key == "expires" {
                    data["Expires"] = val
                }
                if key.contains("updated date") || key == "last updated" {
                    data["Updated"] = val
                }
                if key.contains("domain status") && data["Domain Status"] == nil {
                    data["Domain Status"] = val.components(separatedBy: " ")[0]
                }
                if key == "name server" || key == "nserver" {
                    nameServers.append(val.lowercased())
                }
            }
        }
        
        if !nameServers.isEmpty {
            let uniqueNS = Array(Set(nameServers)).sorted()
            data["Name Servers"] = uniqueNS.joined(separator: "\n")
        }
        
        return [MXRecord(data: data)]
    }

    // --- PING RUNNER ---
    private func runPing(host: String) async -> [MXRecord] {
        let output = shell("ping -c 3 -t 2 \(host)")
        var data: [String: Any] = ["Name": "Ping Statistics", "Target": host]
        
        if output.contains("0% packet loss") { data["Status"] = "[GREEN] OK" }
        else if output.contains("100% packet loss") { data["Status"] = "[RED] Fail" }
        else { data["Status"] = "Partial" }
        
        if let range = output.range(of: "round-trip min/avg/max/stddev = ") {
            let stats = output[range.upperBound...].components(separatedBy: " ms")[0]
            data["Response Time"] = stats
        }
        data["Full Record"] = output
        data["title"] = "Ping Result"
        return [MXRecord(data: data)]
    }
    
    // --- CURL RUNNER ---
    private func runCurl(url: String, secure: Bool) async -> [MXRecord] {
        let proto = secure ? "https" : "http"
        let output = shell("curl -I -L -m 5 \(proto)://\(url)")
        var data: [String: Any] = ["Name": "Web Check", "Target": "\(proto)://\(url)"]
        
        let lines = output.components(separatedBy: .newlines)
        if let first = lines.first {
            data["Status Code"] = first
            if first.contains("200") { data["Status"] = "[GREEN] OK" }
            else { data["Status"] = first }
        }
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { data[parts[0]] = parts[1] }
        }
        data["title"] = "Web Headers"
        return [MXRecord(data: data)]
    }
    
    // --- TRACE ---
    private func runTrace(host: String) async -> [MXRecord] {
        let output = shell("traceroute -m 15 -w 1 \(host)")
        return [MXRecord(data: ["Name": "Traceroute", "Full Record": output, "title": "Trace Route"])]
    }

    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
