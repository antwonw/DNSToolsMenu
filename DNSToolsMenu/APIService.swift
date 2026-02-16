import Foundation
import SwiftUI

class APIService {
    private let baseURL = "https://api.mxtoolbox.com/api/v1/"
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "MX_API_KEY") ?? ""
    }
    
    func performLookup(command: String, argument: String) async throws -> String {
        guard !apiKey.isEmpty else {
            return makeJsonError("Please enter your API Key in Settings.")
        }
        
        let urlString = "\(baseURL)lookup/\(command)/"
        var components = URLComponents(string: urlString)
        components?.queryItems = [
            URLQueryItem(name: "argument", value: argument)
        ]
        
        guard let url = components?.url else { return makeJsonError("Invalid URL generated.") }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorText = String(data: data, encoding: .utf8), !errorText.isEmpty {
                 // Check for HTML error pages
                 if errorText.contains("window.MXT") || errorText.contains("Javascript is disabled") {
                     return makeJsonError("API Request Failed. Ensure your API Key is correct.")
                 }
                 // Check for valid JSON error
                 if errorText.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                     return errorText
                 }
                 return makeJsonError("API Error \(httpResponse.statusCode): \(errorText)")
            }
            return makeJsonError("API Request failed with status code \(httpResponse.statusCode)")
        }
        
        guard let rawString = String(data: data, encoding: .utf8) else {
            return makeJsonError("Unable to decode response data.")
        }
        
        return rawString
    }
    
    func getUsage() async -> APIUsage? {
        guard !apiKey.isEmpty else { return nil }
        let urlString = "\(baseURL)Usage" // Capital U endpoint
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(APIUsage.self, from: data)
        } catch {
            return nil
        }
    }
    
    private func makeJsonError(_ message: String) -> String {
        let clean = message.replacingOccurrences(of: "\n", with: " ")
                           .replacingOccurrences(of: "\"", with: "'")
        return """
        { "Message": "\(clean)", "Name": "Notice", "Status": "Info" }
        """
    }
}
