import SwiftUI
import ServiceManagement

struct SettingsView: View {
    // Shared Settings
    @AppStorage("app_mode") private var appMode: String = "Local" // "Local" or "MXToolbox"
    @State private var launchAtLogin: Bool = false
    
    // Local Mode Settings
    @AppStorage("dns_provider") private var dnsProvider: String = "System"
    @AppStorage("custom_dns_ip") private var customDnsIP: String = ""
    
    // MXToolbox Mode Settings
    @AppStorage("MX_API_KEY") private var apiKey: String = ""
    
    let providers = ["System", "Cloudflare (1.1.1.1)", "Google (8.8.8.8)", "Custom"]
    let modes = ["Local Native", "MXToolbox API"]
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Header (Icon & Title) ---
            VStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                
                VStack(spacing: 2) {
                    Text("DNSTools")
                        .font(.title3).bold()
                    Text("Version 2.1.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider()
            
            // --- Scrollable Form Area ---
            Form {
                // Section 1: Engine Selection
                Section {
                    Picker("Engine Mode", selection: $appMode) {
                        ForEach(modes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                } header: {
                    Text("Operation Mode")
                } footer: {
                    Text(appMode == "Local Native"
                         ? "Runs dig/ping/whois locally. Fast, private, unlimited."
                         : "Uses MXToolbox API. detailed analysis, requires API Key.")
                }
                
                // Section 2: Conditional Configuration
                if appMode == "Local Native" {
                    Section {
                        Picker("DNS Resolver", selection: $dnsProvider) {
                            ForEach(providers, id: \.self) { provider in
                                Text(provider).tag(provider)
                            }
                        }
                        
                        if dnsProvider == "Custom" {
                            TextField("8.8.4.4", text: $customDnsIP)
                        }
                    } header: {
                        Text("Local Configuration")
                    } footer: {
                        Text("Forces 'dig' commands to use this server.")
                    }
                } else {
                    Section {
                        SecureField("MXToolbox API Key", text: $apiKey)
                        
                        if apiKey.isEmpty {
                            Text("⚠️ API Key Required").font(.caption).foregroundStyle(.red)
                        } else {
                            Text("✓ Key Saved").font(.caption).foregroundStyle(.green)
                        }
                        
                        Link("Get API Key", destination: URL(string: "https://mxtoolbox.com/user/api")!)
                            .font(.caption)
                    } header: {
                        Text("API Configuration")
                    }
                }
                
                // Section 3: General
                Section {
                    Toggle("Start at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            toggleLaunchAtLogin(enabled: newValue)
                        }
                } header: {
                    Text("General")
                }
                
                // Section 4: Credits
                Section {
                    Link(destination: URL(string: "https://tabler.io/icons")!) {
                        HStack {
                            Text("Icons by Tabler")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // --- Footer Button ---
            HStack {
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
}
