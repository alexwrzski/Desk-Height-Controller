//
//  ESP32Client.swift
//  DeskController
//
//  HTTP client for ESP32 communication
//

import Foundation

struct StatusResponse {
    let height: Int
}

struct LimitsResponse {
    let min: Int
    let max: Int
}

class ESP32Client {
    var baseURL: String
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func makeRequest(path: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/\(path)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0 // Shorter timeout for faster feedback
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            // Accept any 2xx status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            guard let text = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            
            return text
        } catch {
            // Re-throw with more context
            throw error
        }
    }
    
    func getStatus(completion: @escaping (Result<StatusResponse, Error>) -> Void) async {
        do {
            let text = try await makeRequest(path: "status")
            
            // Use the exact same pattern as the web app: "Current Height: (\d+) mm"
            // This matches the web app's regex: /Current Height: (\d+) mm/
            if let regex = try? NSRegularExpression(pattern: "Current Height: (\\d+) mm", options: []) {
                let nsString = text as NSString
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first, match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    let heightString = nsString.substring(with: range)
                    if let height = Int(heightString) {
                        completion(.success(StatusResponse(height: height)))
                        return
                    }
                }
            }
            
            // If that doesn't work, try case-insensitive
            if let regex = try? NSRegularExpression(pattern: "Current Height: (\\d+) mm", options: [.caseInsensitive]) {
                let nsString = text as NSString
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first, match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    let heightString = nsString.substring(with: range)
                    if let height = Int(heightString) {
                        completion(.success(StatusResponse(height: height)))
                        return
                    }
                }
            }
            
            // If we got a response but can't parse, still throw error (web app does this too)
            throw URLError(.cannotParseResponse)
        } catch {
            completion(.failure(error))
        }
    }
    
    func getLimits(completion: @escaping (Result<LimitsResponse, Error>) -> Void) async {
        do {
            let text = try await makeRequest(path: "limits")
            
            // Parse "Minimum: 575" and "Maximum: 1185"
            let minRegex = try NSRegularExpression(pattern: #"Minimum: (\d+)"#, options: [])
            let maxRegex = try NSRegularExpression(pattern: #"Maximum: (\d+)"#, options: [])
            
            let nsString = text as NSString
            let minMatches = minRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            let maxMatches = maxRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            guard let minMatch = minMatches.first,
                  minMatch.numberOfRanges > 1,
                  let maxMatch = maxMatches.first,
                  maxMatch.numberOfRanges > 1 else {
                throw URLError(.cannotParseResponse)
            }
            
            let minRange = minMatch.range(at: 1)
            let maxRange = maxMatch.range(at: 1)
            let minString = nsString.substring(with: minRange)
            let maxString = nsString.substring(with: maxRange)
            
            guard let min = Int(minString),
                  let max = Int(maxString) else {
                throw URLError(.cannotParseResponse)
            }
            
            completion(.success(LimitsResponse(min: min, max: max)))
        } catch {
            completion(.failure(error))
        }
    }
    
    func sendCommand(_ command: String) async {
        do {
            let encodedCommand = command.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? command
            _ = try await makeRequest(path: encodedCommand)
        } catch {
            print("Error sending command \(command): \(error)")
        }
    }
    
    func testConnection() async -> Bool {
        do {
            let text = try await makeRequest(path: "status")
            return text.contains("ESP32 Desk Controller")
        } catch {
            return false
        }
    }
}

