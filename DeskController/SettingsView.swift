//
//  SettingsView.swift
//  DeskController
//
//  Settings Modal View
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    
    @State private var manualHeight: String = ""
    @State private var connectionStatus: String = "Checking..."
    @State private var connectionStatusColor: String = "#888888"
    @State private var isTestingConnection = false
    @State private var showSuccessAlert = false
    @State private var showResetWiFiConfirmation = false
    @State private var minLimitString: String = ""
    @State private var maxLimitString: String = ""
    @State private var validationWarning: String? = nil
    
    var body: some View {
        ZStack {
            Color(hex: "1a1a1a")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 15) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                        
                        Spacer()
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("×")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 25)
                    .padding(.bottom, 20)
                    
                    // Manual Movement
                    SettingsCard(title: "MANUAL MOVEMENT") {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Target Height (mm)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "888888"))
                                
                                TextField("Height (mm)", text: $manualHeight)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(8)
                                    .background(Color(hex: "111111"))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(hex: "444444"), lineWidth: 1)
                                    )
                            }
                            
                            Button(action: {
                                moveToHeight()
                            }) {
                                Text("Move")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "3b82f6"))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Text("Min: \(appState.minLimit)mm | Max: \(appState.maxLimit)mm")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "888888"))
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 25)
                    
                    // Manage Presets
                    SettingsCard(title: "MANAGE PRESETS") {
                        VStack(spacing: 8) {
                            // Validation warning message
                            if let warning = validationWarning {
                                HStack {
                                    Text("⚠")
                                        .font(.system(size: 14))
                                    Text(warning)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "f87171"))
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(hex: "422222"))
                                .cornerRadius(6)
                                .padding(.bottom, 4)
                            }
                            
                            ForEach(appState.presets) { preset in
                                PresetRow(
                                    name: Binding(
                                        get: { 
                                            appState.presets.first(where: { $0.id == preset.id })?.name ?? ""
                                        },
                                        set: { newValue in
                                            if let index = appState.presets.firstIndex(where: { $0.id == preset.id }) {
                                                appState.updatePreset(at: index, name: newValue)
                                            }
                                        }
                                    ),
                                    height: Binding(
                                        get: { 
                                            String(appState.presets.first(where: { $0.id == preset.id })?.height ?? 0)
                                        },
                                        set: { newValue in
                                            if let h = Int(newValue),
                                               let index = appState.presets.firstIndex(where: { $0.id == preset.id }) {
                                                appState.updatePreset(at: index, height: h)
                                                // Re-validate after updating height
                                                validatePresets()
                                            }
                                        }
                                    ),
                                    onDelete: {
                                        if let index = appState.presets.firstIndex(where: { $0.id == preset.id }) {
                                            appState.removePreset(at: index)
                                            // Re-validate after deleting
                                            validatePresets()
                                        }
                                    }
                                )
                            }
                            
                            Button(action: {
                                guard appState.presets.count < 9 else {
                                    validationWarning = "Maximum of 9 presets reached. Please delete one before adding another."
                                    return
                                }
                                // Clear warning when adding preset
                                validationWarning = nil
                                // Use helper method that enforces limit
                                appState.addNewPreset(Preset(name: "", height: 700))
                                // Re-validate after adding
                                validatePresets()
                            }) {
                                Text(appState.presets.count >= 9 ? "Maximum 9 Presets" : "+ Add Preset")
                                    .font(.system(size: 14))
                                    .foregroundColor(appState.presets.count >= 9 ? Color(hex: "888888") : Color(hex: "3b82f6"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(hex: "555555"), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(appState.presets.count >= 9)
                            .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 25)
                    
                    // Safety Limits
                    SettingsCard(title: "SAFETY LIMITS") {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Min (mm)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "888888"))
                                
                                TextField("", text: $minLimitString)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(8)
                                    .background(Color(hex: "111111"))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(hex: "444444"), lineWidth: 1)
                                    )
                                    .onChange(of: minLimitString) { newValue in
                                        if let value = Int(newValue) {
                                            appState.minLimit = value
                                            // Re-validate when limits change
                                            validatePresets()
                                        }
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max (mm)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "888888"))
                                
                                TextField("", text: $maxLimitString)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(8)
                                    .background(Color(hex: "111111"))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(hex: "444444"), lineWidth: 1)
                                    )
                                    .onChange(of: maxLimitString) { newValue in
                                        if let value = Int(newValue) {
                                            appState.maxLimit = value
                                            // Re-validate when limits change
                                            validatePresets()
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 25)
                    
                    // ESP32 Connection
                    SettingsCard(title: "ESP32 CONNECTION") {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ESP32 IP Address")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "888888"))
                                
                                TextField("http://192.168.1.100", text: $appState.esp32IP)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(8)
                                    .background(Color(hex: "111111"))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(hex: "444444"), lineWidth: 1)
                                    )
                            }
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    testConnection()
                                }) {
                                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "333333"))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isTestingConnection)
                                
                                Button(action: {
                                    saveESP32IP()
                                }) {
                                    Text("Save IP")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "3b82f6"))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Text("Status: \(connectionStatus)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: connectionStatusColor))
                            
                            Button(action: {
                                showResetWiFiConfirmation = true
                            }) {
                                Text("Reset WiFi (Restart Setup Mode)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "f87171"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "422222"))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 25)
                    
                    // Save Button
                    Button(action: {
                        saveAllSettings()
                    }) {
                        Text("Save All Changes")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "3b82f6"))
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .padding(.bottom, 25)
                }
            }
        }
        .frame(width: 400)
        .onAppear {
            updateConnectionStatus()
            minLimitString = String(appState.minLimit)
            maxLimitString = String(appState.maxLimit)
            validatePresets()
        }
        .onChange(of: showResetWiFiConfirmation) { show in
            if show {
                let alert = NSAlert()
                alert.messageText = "Reset WiFi"
                alert.informativeText = "This will reset the ESP32 WiFi settings and restart it in setup mode. Continue?"
                alert.addButton(withTitle: "Reset WiFi")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .warning
                let response = alert.runModal()
                showResetWiFiConfirmation = false
                if response == .alertFirstButtonReturn {
                    resetWiFi()
                }
            }
        }
    }
    
    func moveToHeight() {
        guard let height = Int(manualHeight) else {
            return
        }
        
        if height < appState.minLimit || height > appState.maxLimit {
            validationWarning = "Height \(height)mm is outside the configured limits (\(appState.minLimit)-\(appState.maxLimit)mm). Please adjust the height limits or enter a height within the current limits."
            return
        }
        
        // Clear warning if valid
        validationWarning = nil
        appState.moveToHeight(height)
        manualHeight = ""
    }
    
    func testConnection() {
        isTestingConnection = true
        connectionStatus = "Testing connection..."
        connectionStatusColor = "#888888"
        
        Task {
            let connected = await appState.testConnection()
            await MainActor.run {
                isTestingConnection = false
                if connected {
                    connectionStatus = "✓ Connected"
                    connectionStatusColor = "#4ade80"
                } else {
                    connectionStatus = "✗ Disconnected"
                    connectionStatusColor = "#f87171"
                }
            }
        }
    }
    
    func saveESP32IP() {
        appState.client.baseURL = appState.esp32IP
        testConnection()
    }
    
    func resetWiFi() {
        Task {
            await appState.resetWiFi()
        }
    }
    
    func updateConnectionStatus() {
        if appState.isConnected {
            connectionStatus = "✓ Connected"
            connectionStatusColor = "#4ade80"
        } else {
            connectionStatus = "✗ Disconnected"
            connectionStatusColor = "#f87171"
        }
    }
    
    func validatePresets() {
        // Clear previous warning
        validationWarning = nil
        
        // Check for empty presets
        if appState.presets.isEmpty {
            validationWarning = "Please add at least one preset"
            return
        }
        
        // Check for presets outside limits
        let invalidPresets = appState.presets.filter { preset in
            preset.height < appState.minLimit || preset.height > appState.maxLimit
        }
        
        if !invalidPresets.isEmpty {
            let presetList = invalidPresets.map { "\($0.name): \($0.height)mm" }.joined(separator: ", ")
            validationWarning = "The following presets are outside the height limits (\(appState.minLimit)-\(appState.maxLimit)mm): \(presetList). Please adjust the height limits or change the preset heights."
            return
        }
    }
    
    func saveAllSettings() {
        // Validate presets
        validatePresets()
        
        // If there's a validation warning, don't save
        if validationWarning != nil {
            return
        }
        
        appState.savePresets()
        appState.saveLimits()
        
        // Dismiss immediately after saving
        isPresented = false
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "888888"))
                .textCase(.uppercase)
            
            content
        }
        .padding(18)
        .background(Color(hex: "262626"))
        .cornerRadius(16)
    }
}

struct PresetRow: View {
    @Binding var name: String
    @Binding var height: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $name)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(Color(hex: "111111"))
                .foregroundColor(.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "444444"), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
            
            TextField("mm", text: $height)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(Color(hex: "111111"))
                .foregroundColor(.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "444444"), lineWidth: 1)
                )
                .frame(width: 80)
            
            Button(action: onDelete) {
                Text("×")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "f87171"))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "422222"))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

