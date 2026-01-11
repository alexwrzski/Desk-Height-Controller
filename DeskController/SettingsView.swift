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
            DesignConstants.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 15) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DesignConstants.Colors.textMuted)
                        
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
                            StyledTextField(
                                label: "Target Height (mm)",
                                placeholder: "Height (mm)",
                                text: $manualHeight
                            )

                            Button(action: {
                                moveToHeight()
                            }) {
                                Text("Move")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(DesignConstants.Colors.accentBlue)
                                    .cornerRadius(DesignConstants.Styling.inputCornerRadius)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Text("Min: \(appState.minLimit)mm | Max: \(appState.maxLimit)mm")
                            .font(.system(size: DesignConstants.Typography.labelSize))
                            .foregroundColor(DesignConstants.Colors.textMuted)
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
                                        .font(.system(size: DesignConstants.Typography.labelSize))
                                        .foregroundColor(DesignConstants.Colors.errorRed)
                                    Spacer()
                                }
                                .padding(10)
                                .background(DesignConstants.Colors.errorBackground)
                                .cornerRadius(DesignConstants.Styling.inputCornerRadius)
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
                                    .foregroundColor(appState.presets.count >= 9 ? DesignConstants.Colors.textMuted : DesignConstants.Colors.accentBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignConstants.Styling.inputCornerRadius)
                                            .stroke(DesignConstants.Colors.borderDashed, style: StrokeStyle(lineWidth: DesignConstants.Styling.standardBorderWidth, dash: [5]))
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
                            StyledNumberField(
                                label: "Min (mm)",
                                placeholder: "",
                                value: $minLimitString
                            )
                            .onChange(of: minLimitString) { newValue in
                                if let value = Int(newValue) {
                                    appState.minLimit = value
                                    // Re-validate when limits change
                                    validatePresets()
                                }
                            }

                            StyledNumberField(
                                label: "Max (mm)",
                                placeholder: "",
                                value: $maxLimitString
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
                    .padding(.horizontal, 25)
                    
                    // ESP32 Connection
                    SettingsCard(title: "ESP32 CONNECTION") {
                        VStack(alignment: .leading, spacing: 10) {
                            StyledTextField(
                                label: "ESP32 IP Address",
                                placeholder: "http://192.168.1.100",
                                text: $appState.esp32IP
                            )
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    testConnection()
                                }) {
                                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(DesignConstants.Colors.buttonBackground)
                                        .cornerRadius(DesignConstants.Styling.inputCornerRadius)
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
                                        .background(DesignConstants.Colors.accentBlue)
                                        .cornerRadius(DesignConstants.Styling.inputCornerRadius)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            Text("Status: \(connectionStatus)")
                                .font(.system(size: DesignConstants.Typography.labelSize))
                                .foregroundColor(Color(hex: connectionStatusColor))

                            Button(action: {
                                showResetWiFiConfirmation = true
                            }) {
                                Text("Reset WiFi (Restart Setup Mode)")
                                    .font(.system(size: DesignConstants.Typography.statusSize))
                                    .foregroundColor(DesignConstants.Colors.errorRed)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(DesignConstants.Colors.errorBackground)
                                    .cornerRadius(DesignConstants.Styling.inputCornerRadius)
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
                            .background(DesignConstants.Colors.accentBlue)
                            .cornerRadius(DesignConstants.Styling.buttonCornerRadius)
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
        VStack(alignment: .leading, spacing: DesignConstants.Layout.sectionSpacing) {
            Text(title)
                .font(.system(size: DesignConstants.Typography.statusSize, weight: .bold))
                .foregroundColor(DesignConstants.Colors.textMuted)
                .textCase(.uppercase)

            content
        }
        .padding(DesignConstants.Layout.cardPadding)
        .background(DesignConstants.Colors.cardBackground)
        .cornerRadius(16)
    }
}

struct PresetRow: View {
    @Binding var name: String
    @Binding var height: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: DesignConstants.Layout.presetSpacing) {
            TextField("Name", text: $name)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(DesignConstants.Colors.inputBackground)
                .foregroundColor(.white)
                .cornerRadius(DesignConstants.Styling.inputCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.Styling.inputCornerRadius)
                        .stroke(DesignConstants.Colors.border, lineWidth: DesignConstants.Styling.standardBorderWidth)
                )
                .frame(maxWidth: .infinity)

            TextField("mm", text: $height)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(DesignConstants.Colors.inputBackground)
                .foregroundColor(.white)
                .cornerRadius(DesignConstants.Styling.inputCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.Styling.inputCornerRadius)
                        .stroke(DesignConstants.Colors.border, lineWidth: DesignConstants.Styling.standardBorderWidth)
                )
                .frame(width: 80)

            Button(action: onDelete) {
                Text("×")
                    .font(.system(size: 18))
                    .foregroundColor(DesignConstants.Colors.errorRed)
                    .frame(width: 30, height: 30)
                    .background(DesignConstants.Colors.errorBackground)
                    .cornerRadius(DesignConstants.Styling.inputCornerRadius)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

