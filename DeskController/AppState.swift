//
//  AppState.swift
//  DeskController
//
//  Observable state management for the app
//

import Foundation
import Combine

class AppState: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    @Published var currentHeight: Int? = nil
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = "Connecting..."
    @Published var statusColor: String = "#888888"
    @Published var isMoving: Bool = false
    
    private var _presets: [Preset] = [
        Preset(name: "Sit", height: 700),
        Preset(name: "Stand", height: 1100),
        Preset(name: "Focus", height: 850)
    ]
    
    var presets: [Preset] {
        get {
            return _presets
        }
        set {
            // Always enforce 9 preset maximum
            let limited = Array(newValue.prefix(9))
            _presets = limited
            objectWillChange.send()
        }
    }
    
    // Helper methods to modify presets while enforcing limit
    func updatePreset(at index: Int, name: String? = nil, height: Int? = nil) {
        guard index < _presets.count else { return }
        if let name = name {
            _presets[index].name = name
        }
        if let height = height {
            _presets[index].height = height
        }
        objectWillChange.send()
    }
    
    func removePreset(at index: Int) {
        guard index < _presets.count else { return }
        _presets.remove(at: index)
        objectWillChange.send()
    }
    
    func addNewPreset(_ preset: Preset) {
        guard _presets.count < 9 else { return }
        _presets.append(preset)
        objectWillChange.send()
    }
    
    @Published var minLimit: Int = 575
    @Published var maxLimit: Int = 1185
    
    @Published var esp32IP: String {
        didSet {
            UserDefaults.standard.set(esp32IP, forKey: "esp32_ip")
            client.baseURL = esp32IP
        }
    }
    
    private var pollingTimer: Timer?
    private var movementTimer: Timer?
    private var lastMovementTime: Date?
    let client: ESP32Client
    
    init() {
        // Load saved ESP32 IP or use default - must be first
        let savedIP = UserDefaults.standard.string(forKey: "esp32_ip") ?? "http://192.168.4.1"
        
        // Initialize client first with the IP
        self.client = ESP32Client(baseURL: savedIP)
        
        // Now initialize esp32IP (which will trigger didSet, but client is already set)
        self.esp32IP = savedIP
        
        // Load saved presets (enforce 9 max)
        if let presetsData = UserDefaults.standard.data(forKey: "deskPresets"),
           let decoded = try? JSONDecoder().decode([Preset].self, from: presetsData) {
            self.presets = Array(decoded.prefix(9)) // Limit to 9 presets
        }
        
        // Load saved limits
        if let min = UserDefaults.standard.object(forKey: "minLimit") as? Int {
            self.minLimit = min
        }
        if let max = UserDefaults.standard.object(forKey: "maxLimit") as? Int {
            self.maxLimit = max
        }
        
        // Load limits from ESP32
        Task {
            await loadLimits()
        }
    }
    
    func startPolling() {
        // Stop any existing timers first
        stopPolling()
        
        print("🚀 startPolling() called, ESP32 IP: \(client.baseURL)")
        
        // Update immediately - this will check connection and update status
        updateHeight()
        
        // Start with idle polling (every 10 seconds) - just to check connection
        // Wait a bit longer to ensure initial check completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startIdlePolling()
        }
    }
    
    func startIdlePolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.updateHeight()
        }
        RunLoop.main.add(pollingTimer!, forMode: .common)
    }
    
    func startMovementPolling() {
        // Stop idle polling
        pollingTimer?.invalidate()
        
        // Mark as moving
        isMoving = true
        lastMovementTime = Date()
        
        // Poll frequently while moving (every 0.5 seconds)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateHeight()
        }
        RunLoop.main.add(pollingTimer!, forMode: .common)
        
        // Schedule a timer to stop movement polling after 2 seconds of no movement
        movementTimer?.invalidate()
        movementTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // If no movement for 2 seconds, switch back to idle polling
            if let lastMove = self.lastMovementTime, Date().timeIntervalSince(lastMove) >= 2.0 {
                self.isMoving = false
                self.startIdlePolling()
                timer.invalidate()
            }
        }
        RunLoop.main.add(movementTimer!, forMode: .common)
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        movementTimer?.invalidate()
        movementTimer = nil
        isMoving = false
    }
    
    func updateHeight() {
        // Simple approach - use URLSession directly like web app's fetch
        // Ensure baseURL doesn't have trailing slash
        var baseURL = client.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
            baseURL = "http://" + baseURL
        }
        
        guard let url = URL(string: "\(baseURL)/status") else {
            print("❌ Invalid URL: \(baseURL)/status")
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.statusMessage = "Disconnected"
                self?.statusColor = "#f87171"
                self?.currentHeight = nil
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0  // Increased timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        print("🔍 Making request to: \(url.absoluteString)")
        
        // Use async/await for more reliable network handling
        Task { @MainActor in
            do {
                print("🌐 Starting network request...")
                let (data, response) = try await URLSession.shared.data(for: request)
                print("📦 Received response, processing...")
                self.handleResponse(data: data, response: response, error: nil)
            } catch {
                print("💥 Network request failed: \(error.localizedDescription)")
                self.handleResponse(data: nil, response: nil, error: error)
            }
        }
    }
    
    private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
                    print("❌ Request error: \(error.localizedDescription)")
                    print("   Error domain: \((error as NSError).domain)")
                    print("   Error code: \((error as NSError).code)")
                    self.isConnected = false
                    self.statusMessage = "Disconnected"
                    self.statusColor = "#f87171"
                    self.currentHeight = nil
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    self.isConnected = false
                    self.statusMessage = "Disconnected"
                    self.statusColor = "#f87171"
                    return
                }
                
                print("✅ Got HTTP response: \(httpResponse.statusCode)")
                
                // Check if HTTP status is successful (200-299)
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ HTTP status code not successful: \(httpResponse.statusCode)")
                    self.isConnected = false
                    self.statusMessage = "Disconnected"
                    self.statusColor = "#f87171"
                    self.currentHeight = nil // Clear height on error
                    return
                }
                
                guard let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    print("❌ Could not decode response")
                    self.isConnected = false
                    self.statusMessage = "Disconnected"
                    self.statusColor = "#f87171"
                    self.currentHeight = nil // Clear height on error
                    return
                }
                
                print("📄 Response text (first 500 chars):")
                print(String(text.prefix(500)))
                print("📏 Full length: \(text.count) characters")
                
                // Try multiple regex patterns to match the height with different options
                // Try exact patterns first, then more flexible ones
                let patternConfigs: [(pattern: String, options: NSRegularExpression.Options)] = [
                    ("Current Height: (\\d+) mm", []),  // Exact match - most common
                    ("Current Height:\\s*(\\d+)\\s*mm", []),  // Flexible whitespace
                    ("Current Height: (\\d+) mm", [.caseInsensitive]),  // Case-insensitive exact
                    ("Current Height:\\s*(\\d+)\\s*mm", [.caseInsensitive]),  // Case-insensitive + flexible whitespace
                    ("Current\\s+Height:\\s*(\\d+)\\s*mm", [.caseInsensitive]),  // Very flexible whitespace
                    ("[Hh]eight:\\s*(\\d+)\\s*mm", []),  // Fallback: any "Height: X mm" pattern
                ]
                
                var heightFound = false
                for config in patternConfigs {
                    if let regex = try? NSRegularExpression(pattern: config.pattern, options: config.options) {
                        let nsString = text as NSString
                        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                        
                        print("🔎 Pattern '\(config.pattern)' (options: \(config.options)) found \(results.count) matches")
                        
                        if let match = results.first, match.numberOfRanges > 1 {
                            let range = match.range(at: 1)
                            let heightString = nsString.substring(with: range)
                            print("📊 Extracted height string: '\(heightString)'")
                            if let height = Int(heightString) {
                                print("✅ SUCCESS! Setting height to \(height)mm")
                                self.currentHeight = height
                                self.isConnected = true
                                self.statusMessage = "Connected"
                                self.statusColor = "#4ade80"
                                print("✅ UI updated - statusMessage: \(self.statusMessage), height: \(self.currentHeight ?? -1)")
                                heightFound = true
                                break
                            } else {
                                print("❌ Could not convert '\(heightString)' to Int")
                            }
                        }
                    }
                }
                
                // If we got here and didn't find height, parsing failed
                if !heightFound {
                    print("⚠️ Parsing failed - no height found in response")
                    // If we got a valid HTTP response but can't parse height,
                    // we're connected but can't read the height
                    self.isConnected = true
                    self.statusMessage = "Connected"
                    self.statusColor = "#4ade80"
                    // Clear currentHeight to show "---" in UI
                    // This way user sees they're connected but height isn't available
                    self.currentHeight = nil
                }
    }
    
    func sendCommand(_ command: String) {
        Task {
            await client.sendCommand(command)
        }
    }
    
    func moveUp() {
        startMovementPolling()
        lastMovementTime = Date() // Update movement time
        sendCommand("up")
    }
    
    func moveDown() {
        startMovementPolling()
        lastMovementTime = Date() // Update movement time
        sendCommand("down")
    }
    
    func stop() {
        sendCommand("stop")
        // Update last movement time - will trigger stop after 2 seconds
        lastMovementTime = Date()
    }
    
    func goToPreset(_ index: Int) {
        guard index < presets.count else { return }
        startMovementPolling()
        sendCommand("goto\(index)")
    }
    
    func moveToHeight(_ height: Int) {
        startMovementPolling()
        sendCommand("height\(height)")
    }
    
    func loadLimits() async {
        await client.getLimits { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let limits) = result {
                    self?.minLimit = limits.min
                    self?.maxLimit = limits.max
                }
            }
        }
    }
    
    func savePresets() {
        // Enforce 9 preset maximum - be very strict
        let limitedPresets = Array(presets.prefix(9))
        if presets.count != limitedPresets.count {
            presets = limitedPresets
        }
        
        if let encoded = try? JSONEncoder().encode(limitedPresets) {
            UserDefaults.standard.set(encoded, forKey: "deskPresets")
        }
        
        // Save to ESP32 (limit to 3 presets)
        let presetsToSave = Array(presets.prefix(3))
        for (index, preset) in presetsToSave.enumerated() {
            Task {
                await client.sendCommand("set\(index) \(preset.height)")
            }
        }
    }
    
    func addPreset(_ preset: Preset) {
        guard presets.count < 9 else { return }
        var newPresets = presets
        newPresets.append(preset)
        presets = Array(newPresets.prefix(9)) // Enforce limit
    }
    
    func saveLimits() {
        UserDefaults.standard.set(minLimit, forKey: "minLimit")
        UserDefaults.standard.set(maxLimit, forKey: "maxLimit")
        
        Task {
            await client.sendCommand("setmin\(minLimit)")
            await client.sendCommand("setmax\(maxLimit)")
        }
    }
    
    func testConnection() async -> Bool {
        return await client.testConnection()
    }
    
    func resetWiFi() async {
        await client.sendCommand("resetwifi")
        // Reset to AP mode IP
        esp32IP = "http://192.168.4.1"
    }
}

struct Preset: Codable, Identifiable {
    let id: UUID
    var name: String
    var height: Int
    
    init(name: String, height: Int) {
        self.id = UUID()
        self.name = name
        self.height = height
    }
}

