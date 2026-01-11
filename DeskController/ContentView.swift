//
//  ContentView.swift
//  DeskController
//
//  Main UI View
//

import SwiftUI
import AppKit

// Preference key to pass window height to window configuration
struct WindowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 600
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var isMovingUp = false
    @State private var isMovingDown = false
    @State private var moveTimer: Timer?
    
    // Calculate window height based on number of presets
    var windowHeight: CGFloat {
        let numberOfRows = ceil(CGFloat(appState.presets.count) / 3.0)
        let presetsHeight = DesignConstants.Layout.presetSectionHeader +
                          (numberOfRows * DesignConstants.Layout.presetButtonHeight) +
                          ((numberOfRows - 1) * DesignConstants.Layout.presetSpacing) +
                          36 // 18 top + 18 bottom padding

        let total = DesignConstants.Layout.windowTopPadding +
                   DesignConstants.Layout.headerHeight +
                   DesignConstants.Layout.controlsHeight +
                   presetsHeight +
                   DesignConstants.Layout.settingsButtonHeight

        return max(total, DesignConstants.Layout.windowMinHeight)
    }
    
    var body: some View {
        // Background - gray like the card
        ZStack {
            DesignConstants.Colors.background
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // App window container
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Current Height")
                        .font(.system(size: 14))
                        .foregroundColor(DesignConstants.Colors.textMuted)

                    Text(appState.currentHeight != nil ? "\(appState.currentHeight!) mm" : "---")
                        .font(.system(size: DesignConstants.Typography.heightDisplaySize, weight: DesignConstants.Typography.heightDisplayWeight))
                        .foregroundColor(appState.currentHeight != nil ? DesignConstants.Colors.accentBlue : DesignConstants.Colors.textMuted)
                        .id("height-\(appState.currentHeight ?? -1)") // Force view update when height changes
                        .animation(.easeInOut(duration: 0.2), value: appState.currentHeight)

                    Text(appState.statusMessage)
                        .font(.system(size: DesignConstants.Typography.statusSize))
                        .foregroundColor(Color(hex: appState.statusColor))

                    // Debug info (only in debug builds)
                    #if DEBUG
                    if appState.currentHeight == nil {
                        Text("ESP32: \(appState.esp32IP)")
                            .font(.system(size: 10))
                            .foregroundColor(DesignConstants.Colors.textDimmed)
                            .padding(.top, 4)
                    }
                    #endif
                }
                .padding(.top, 25)
                .padding(.bottom, 25)
                
                // Main Controls Card
                VStack(spacing: 10) {
                    HoldableButton(
                        label: "▲ UP",
                        backgroundColor: DesignConstants.Colors.successGreen,
                        foregroundColor: DesignConstants.Colors.background,
                        onPress: {
                            startMoving(direction: .up)
                        },
                        onRelease: {
                            stopMoving()
                        }
                    )
                    .frame(height: 50)

                    HoldableButton(
                        label: "▼ DOWN",
                        backgroundColor: DesignConstants.Colors.accentBlue,
                        foregroundColor: .white,
                        onPress: {
                            startMoving(direction: .down)
                        },
                        onRelease: {
                            stopMoving()
                        }
                    )
                    .frame(height: 50)

                    Button(action: {
                        appState.stop()
                        stopMoving()
                    }) {
                        Text("STOP")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(DesignConstants.Colors.errorRed)
                            .foregroundColor(.white)
                            .cornerRadius(DesignConstants.Styling.buttonCornerRadius)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(DesignConstants.Layout.cardPadding)
                .background(DesignConstants.Colors.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 25)
                .padding(.bottom, 15)
                
                // Presets Card
                VStack(alignment: .leading, spacing: DesignConstants.Layout.sectionSpacing) {
                    Text("QUICK PRESETS")
                        .font(.system(size: DesignConstants.Typography.statusSize, weight: .bold))
                        .foregroundColor(DesignConstants.Colors.textMuted)
                        .textCase(.uppercase)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DesignConstants.Layout.presetSpacing) {
                        ForEach(Array(appState.presets.enumerated()), id: \.element.id) { index, preset in
                            Button(action: {
                                appState.goToPreset(index)
                            }) {
                                Text(preset.name)
                                    .font(.system(size: DesignConstants.Typography.presetButtonSize))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: DesignConstants.Layout.presetButtonHeight)
                                    .background(DesignConstants.Colors.presetButtonBackground)
                                    .foregroundColor(.white)
                                    .cornerRadius(DesignConstants.Styling.buttonCornerRadius)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(DesignConstants.Layout.cardPadding)
                .background(DesignConstants.Colors.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 25)
                .padding(.bottom, 15)

                // Settings Button
                Button(action: {
                    showSettings = true
                }) {
                    Text("⚙ Settings")
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .background(DesignConstants.Colors.buttonBackground)
                        .foregroundColor(DesignConstants.Colors.textMuted)
                        .cornerRadius(DesignConstants.Styling.buttonCornerRadius)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 25)
                .padding(.bottom, 50) // More bottom padding for better spacing
                }
                .frame(width: 280) // Fixed width, dynamic height
                .padding(.top, DesignConstants.Layout.windowTopPadding)
        }
        .frame(width: DesignConstants.Layout.windowWidth)
        .frame(minHeight: windowHeight, idealHeight: windowHeight, maxHeight: windowHeight)
        .fixedSize(horizontal: true, vertical: true) // Fix both dimensions to prevent scrolling
        .preference(key: WindowHeightKey.self, value: windowHeight)
        .onChange(of: appState.presets.count) { _ in
            // Enforce preset limit and update window size
            if appState.presets.count > 9 {
                appState.presets = Array(appState.presets.prefix(9))
            }
            updateWindowSize()
        }
        .onAppear {
            // Enforce preset limit on appear
            if appState.presets.count > 9 {
                appState.presets = Array(appState.presets.prefix(9))
            }
            updateWindowSize()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
                .environmentObject(appState)
        }
    }
    
    enum MoveDirection {
        case up, down
    }
    
    func startMoving(direction: MoveDirection) {
        stopMoving() // Stop any existing movement
        
        switch direction {
        case .up:
            isMovingUp = true
            appState.moveUp()
        case .down:
            isMovingDown = true
            appState.moveDown()
        }
        
        // Continue sending commands every 200ms
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak appState] _ in
            switch direction {
            case .up:
                appState?.moveUp()
            case .down:
                appState?.moveDown()
            }
        }
    }
    
    func stopMoving() {
        moveTimer?.invalidate()
        moveTimer = nil
        isMovingUp = false
        isMovingDown = false
        appState.stop()
    }
    
    func updateWindowSize() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                let oldFrame = window.frame
                let contentSize = NSSize(width: DesignConstants.Layout.windowWidth, height: self.windowHeight)
                let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
                
                // Calculate new origin to keep top edge fixed
                let heightDifference = frameSize.height - oldFrame.size.height
                let newOrigin = NSPoint(x: oldFrame.origin.x, y: oldFrame.origin.y - heightDifference)
                let newFrame = NSRect(origin: newOrigin, size: frameSize)
                
                // Animate the resize smoothly, keeping top edge fixed
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.allowsImplicitAnimation = true
                    window.setFrame(newFrame, display: true)
                }
                
                window.contentMinSize = contentSize
                window.contentMaxSize = contentSize
                
                // Update locked size in delegate
                WindowDelegate.shared.setLockedSize(frameSize)
                
                // Force non-resizable - be very aggressive
                var styleMask = window.styleMask
                styleMask.remove(.resizable)
                styleMask.remove(.fullSizeContentView)
                window.styleMask = styleMask
                
                // Ensure delegate is set
                if window.delegate == nil {
                    window.delegate = WindowDelegate.shared
                }
            }
        }
    }
}

