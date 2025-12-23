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
    private var lastHeightValue: Int? = nil
    private var stableHeightCount: Int = 0
    private var heightUpdatePaused: Bool = false
    private var heightChangeDetected: Bool = false
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
        // When idle and height is stable, don't poll for height updates
        // Only poll occasionally for connection status (every 30 seconds)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            // Just check connection, don't update height when stable
            guard let self = self else { return }
            if !self.heightUpdatePaused {
                self.updateHeight()
            } else {
                // Height is stable, just check connection status without updating height
                self.checkConnectionOnly()
            }
        }
        RunLoop.main.add(pollingTimer!, forMode: .common)
    }
    
    func startMovementPolling() {
        // Stop idle polling
        pollingTimer?.invalidate()
        
        // Mark as moving and resume height updates
        // This is called when movement starts (up/down/preset buttons)
        isMoving = true
        heightUpdatePaused = false
        stableHeightCount = 0
        heightChangeDetected = false
        lastMovementTime = Date()
        
        print("🚀 startMovementPolling() - isMoving set to true")
        
        // Poll frequently while moving (every 0.5 seconds)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Ensure isMoving stays true while polling
            if !self.isMoving {
                print("⚠️ isMoving was false during movement polling - resetting to true")
                self.isMoving = true
            }
            self.updateHeight()
        }
        RunLoop.main.add(pollingTimer!, forMode: .common)
        
        // Don't automatically stop - let height change detection determine when to stop
        // The movement detection will happen in updateHeight based on actual height changes
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        movementTimer?.invalidate()
        movementTimer = nil
        isMoving = false
        heightUpdatePaused = false
        stableHeightCount = 0
    }
    
    func checkConnectionOnly() {
        // Check connection status without updating height
        // This is used when height is stable to just verify connection
        Task {
            let connected = await client.testConnection()
            await MainActor.run {
                if connected {
                    self.isConnected = true
                    self.statusMessage = "Connected"
                    self.statusColor = "#4ade80"
                } else {
                    self.isConnected = false
                    self.statusMessage = "Disconnected"
                    self.statusColor = "#f87171"
                }
            }
        }
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
        Task {
            do {
                print("🌐 Starting network request...")
                let (data, response) = try await URLSession.shared.data(for: request)
                print("📦 Received response, processing...")
                // Ensure we process on main thread for UI updates
                await MainActor.run {
                    self.handleResponse(data: data, response: response, error: nil)
                }
            } catch {
                print("💥 Network request failed: \(error.localizedDescription)")
                // Ensure we process on main thread for UI updates
                await MainActor.run {
                    self.handleResponse(data: nil, response: nil, error: error)
                }
            }
        }
    }
    
    @MainActor
    private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
        // This function is now guaranteed to run on MainActor/main thread
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
                
                // Clean the text - remove HTML tags and normalize whitespace
                var cleanText = text
                // Remove HTML tags if present
                cleanText = cleanText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                // Normalize whitespace
                cleanText = cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                print("🧹 Cleaned text (first 500 chars):")
                print(String(cleanText.prefix(500)))
                
                // Try multiple regex patterns to match the height with different options
                // Try exact patterns first, then more flexible ones
                let patternConfigs: [(pattern: String, options: NSRegularExpression.Options)] = [
                    ("Current Height: (\\d+) mm", [.caseInsensitive]),  // Case-insensitive - matches both "Height" and "height"
                    ("Current Height:\\s*(\\d+)\\s*mm", [.caseInsensitive]),  // Flexible whitespace + case-insensitive
                    ("Current\\s+Height:\\s*(\\d+)\\s*mm", [.caseInsensitive]),  // Very flexible whitespace + case-insensitive
                    ("Current[Hh]eight:\\s*(\\d+)\\s*mm", []),  // Explicit case variants
                    ("[Cc]urrent\\s+[Hh]eight:\\s*(\\d+)\\s*mm", []),  // Both words case variants
                    ("[Hh]eight:\\s*(\\d+)\\s*mm", []),  // Fallback: any "Height: X mm" pattern
                ]
                
                var heightFound = false
                // Try patterns on both original and cleaned text
                let textsToSearch = [text, cleanText]
                
                for searchText in textsToSearch {
                    for config in patternConfigs {
                        if let regex = try? NSRegularExpression(pattern: config.pattern, options: config.options) {
                            let nsString = searchText as NSString
                            let results = regex.matches(in: searchText, options: [], range: NSRange(location: 0, length: nsString.length))
                            
                            print("🔎 Pattern '\(config.pattern)' (options: \(config.options)) found \(results.count) matches")
                            
                            if let match = results.first, match.numberOfRanges > 1 {
                                let range = match.range(at: 1)
                                let heightString = nsString.substring(with: range)
                                print("📊 Extracted height string: '\(heightString)'")
                                if let height = Int(heightString) {
                                    print("✅ SUCCESS! Setting height to \(height)mm")
                                    // We're on main thread (@MainActor)
                                    
                                    // If isMoving is true (set by button press), ALWAYS update height (live view)
                                    if self.isMoving {
                                        // Check if height is actually changing
                                        let heightChanged: Bool
                                        if let lastHeight = self.lastHeightValue {
                                            heightChanged = abs(height - lastHeight) > 2 // Changed by more than 2mm
                                        } else {
                                            heightChanged = true // First reading
                                        }
                                        
                                        if heightChanged {
                                            // Height is changing - desk is moving, reset stability counter
                                            self.stableHeightCount = 0
                                            print("📊 Height changing - updated to \(height)mm (live view)")
                                        } else {
                                            // Height is stable - check if desk has stopped
                                            self.stableHeightCount += 1
                                            if self.stableHeightCount >= 4 {
                                                // Height stable for 4 polls (2 seconds), desk has stopped
                                                print("🛑 Desk stopped - height stabilized at \(height)mm")
                                                self.isMoving = false
                                                self.heightUpdatePaused = true
                                                self.startIdlePolling() // Switch to idle polling
                                            } else {
                                                print("📊 Still moving (stable count: \(self.stableHeightCount)) - updated to \(height)mm")
                                            }
                                        }
                                        
                                        // Always update height when isMoving is true (live view)
                                        self.objectWillChange.send() // Explicitly trigger UI update
                                        self.currentHeight = height
                                        self.lastHeightValue = height
                                    } else {
                                        // Not moving - check if height is stable
                                        let heightChanged: Bool
                                        if let lastHeight = self.lastHeightValue {
                                            heightChanged = abs(height - lastHeight) > 2
                                        } else {
                                            heightChanged = true
                                        }
                                        
                                        if heightChanged {
                                            // Height changed but we're not in moving state - update once
                                            self.stableHeightCount = 0
                                            self.heightUpdatePaused = false
                                            self.objectWillChange.send()
                                            self.currentHeight = height
                                            self.lastHeightValue = height
                                            print("📊 Height changed to \(height)mm (not moving)")
                                        } else {
                                            // Height is stable
                                            self.stableHeightCount += 1
                                            if self.stableHeightCount >= 3 && !self.heightUpdatePaused {
                                                // First time detecting stability, pause updates
                                                self.heightUpdatePaused = true
                                                print("🛑 Height stable at \(height)mm - pausing updates")
                                            }
                                            // Don't update when paused
                                        }
                                    }
                                    
                                    self.isConnected = true
                                    self.statusMessage = "Connected"
                                    self.statusColor = "#4ade80"
                                    print("✅ UI updated - statusMessage: \(self.statusMessage), height: \(self.currentHeight ?? -1), isMoving: \(self.isMoving)")
                                    heightFound = true
                                    break
                                } else {
                                    print("❌ Could not convert '\(heightString)' to Int")
                                }
                            }
                        }
                    }
                    if heightFound { break }
                }
                
                // If we got here and didn't find height, parsing failed
                if !heightFound {
                    print("⚠️ Parsing failed - no height found in response")
                    print("🔍 Full response text:")
                    print(text)
                    print("🔍 Cleaned response text:")
                    print(cleanText)
                    // If we got a valid HTTP response but can't parse height,
                    // we're connected but can't read the height
                    // We're already on main thread (checked at start of handleResponse)
                    self.isConnected = true
                    self.statusMessage = "Connected (no height)"
                    self.statusColor = "#fbbf24" // Yellow/orange to indicate partial connection
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
        // Resume height updates when starting movement
        // This is called repeatedly while button is held (every 200ms)
        // Ensure isMoving stays true
        if !isMoving {
            print("🔼 moveUp() called - starting movement polling")
            startMovementPolling()
        } else {
            // Already moving, just update the last movement time
            lastMovementTime = Date()
        }
        heightUpdatePaused = false
        stableHeightCount = 0
        sendCommand("up")
    }
    
    func moveDown() {
        // Resume height updates when starting movement
        // This is called repeatedly while button is held (every 200ms)
        // Ensure isMoving stays true
        if !isMoving {
            print("🔽 moveDown() called - starting movement polling")
            startMovementPolling()
        } else {
            // Already moving, just update the last movement time
            lastMovementTime = Date()
        }
        heightUpdatePaused = false
        stableHeightCount = 0
        sendCommand("down")
    }
    
    func stop() {
        sendCommand("stop")
        // Update last movement time - will trigger stop after 2 seconds
        lastMovementTime = Date()
    }
    
    func goToPreset(_ index: Int) {
        guard index < presets.count else { return }
        // Resume height updates when starting movement
        heightUpdatePaused = false
        stableHeightCount = 0
        startMovementPolling()
        sendCommand("goto\(index)")
    }
    
    func moveToHeight(_ height: Int) {
        // Resume height updates when starting movement
        heightUpdatePaused = false
        stableHeightCount = 0
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

