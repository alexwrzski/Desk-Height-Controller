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
        let headerHeight: CGFloat = 110 // Header section (Current Height + status) - 25 top + 25 bottom + 60 content
        let controlsHeight: CGFloat = 218 // Main controls card - 18 padding + 200 buttons (50*3 + 20 spacing) + 18 padding
        let presetSectionHeader: CGFloat = 30 // "QUICK PRESETS" label
        let presetButtonHeight: CGFloat = 40 // Height of each preset button
        let presetSpacing: CGFloat = 8 // Spacing between preset buttons
        let numberOfRows = ceil(CGFloat(appState.presets.count) / 3.0)
        let presetsHeight = presetSectionHeader + (numberOfRows * presetButtonHeight) + ((numberOfRows - 1) * presetSpacing) + 36 // 18 top + 18 bottom padding
        let settingsButtonHeight: CGFloat = 95 // Settings button (45) + 50 bottom padding
        let topPadding: CGFloat = 10 // Top padding
        
        let total = topPadding + headerHeight + controlsHeight + presetsHeight + settingsButtonHeight
        return max(total, 500) // Minimum height of 500
    }
    
    var body: some View {
        // Background - gray like the card
        ZStack {
            Color(hex: "1a1a1a")
                .ignoresSafeArea()
            
            // App window container
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Current Height")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "888888"))
                    
                    Text(appState.currentHeight != nil ? "\(appState.currentHeight!) mm" : "---")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(appState.currentHeight != nil ? Color(hex: "3b82f6") : Color(hex: "888888"))
                        .id("height-\(appState.currentHeight ?? -1)") // Force view update when height changes
                        .animation(.easeInOut(duration: 0.2), value: appState.currentHeight)
                    
                    Text(appState.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: appState.statusColor))
                    
                    // Debug info (only in debug builds)
                    #if DEBUG
                    if appState.currentHeight == nil {
                        Text("ESP32: \(appState.esp32IP)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "666666"))
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
                        backgroundColor: Color(hex: "4ade80"),
                        foregroundColor: Color(hex: "1a1a1a"),
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
                        backgroundColor: Color(hex: "3b82f6"),
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
                            .background(Color(hex: "f87171"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(18)
                .background(Color(hex: "262626"))
                .cornerRadius(16)
                .padding(.horizontal, 25)
                .padding(.bottom, 15)
                
                // Presets Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("QUICK PRESETS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "888888"))
                        .textCase(.uppercase)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(appState.presets.enumerated()), id: \.element.id) { index, preset in
                            Button(action: {
                                appState.goToPreset(index)
                            }) {
                                Text(preset.name)
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(Color(hex: "3f3f3f"))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(18)
                .background(Color(hex: "262626"))
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
                        .background(Color(hex: "333333"))
                        .foregroundColor(Color(hex: "888888"))
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 25)
                .padding(.bottom, 50) // More bottom padding for better spacing
                }
                .frame(width: 280) // Fixed width, dynamic height
                .padding(.top, 10) // Top padding
        }
        .frame(width: 300)
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
                let contentSize = NSSize(width: 300, height: self.windowHeight)
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

// Holdable Button for continuous movement using NSViewRepresentable
struct HoldableButton: NSViewRepresentable {
    let label: String
    let backgroundColor: Color
    let foregroundColor: Color
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func makeNSView(context: Context) -> CustomButton {
        let button = CustomButton()
        button.label = label
        button.backgroundColor = backgroundColor
        button.foregroundColor = foregroundColor
        button.onPress = onPress
        button.onRelease = onRelease
        button.setup()
        return button
    }
    
    func updateNSView(_ nsView: CustomButton, context: Context) {
        nsView.label = label
        nsView.backgroundColor = backgroundColor
        nsView.foregroundColor = foregroundColor
        nsView.onPress = onPress
        nsView.onRelease = onRelease
        nsView.updateAppearance()
    }
}

class CustomButton: NSView {
    var label: String = ""
    var backgroundColor: Color = .clear
    var foregroundColor: Color = .black
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    
    private var labelLayer: CATextLayer?
    private var backgroundLayer: CALayer?
    private var isPressed = false
    
    func setup() {
        wantsLayer = true
        layer?.cornerRadius = 10
        
        // Background layer
        backgroundLayer = CALayer()
        backgroundLayer?.cornerRadius = 10
        layer?.addSublayer(backgroundLayer!)
        
        // Label layer
        labelLayer = CATextLayer()
        labelLayer?.alignmentMode = .center
        labelLayer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        labelLayer?.isWrapped = false
        layer?.addSublayer(labelLayer!)
        
        updateAppearance()
    }
    
    func updateAppearance() {
        guard let backgroundLayer = backgroundLayer, let labelLayer = labelLayer else { return }
        
        // Update background
        if let cgColor = backgroundColor.cgColor {
            backgroundLayer.backgroundColor = cgColor
        }
        
        // Update text
        labelLayer.string = label
        if let cgColor = foregroundColor.cgColor {
            labelLayer.foregroundColor = cgColor
        }
        labelLayer.font = NSFont.boldSystemFont(ofSize: 16)
        labelLayer.fontSize = 16
        
        // Center the text properly
        let font = NSFont.boldSystemFont(ofSize: 16)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (label as NSString).size(withAttributes: attributes)
        labelLayer.frame = CGRect(
            x: 0,
            y: (bounds.height - size.height) / 2 - 2, // Slight adjustment for centering
            width: bounds.width,
            height: size.height
        )
    }
    
    override func layout() {
        super.layout()
        backgroundLayer?.frame = bounds
        updateAppearance() // Re-center text on layout
    }
    
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updatePressedState()
        onPress?()
    }
    
    override func mouseUp(with event: NSEvent) {
        if isPressed {
            isPressed = false
            updatePressedState()
            onRelease?()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if isPressed {
            isPressed = false
            updatePressedState()
            onRelease?()
        }
    }
    
    private func updatePressedState() {
        guard let backgroundLayer = backgroundLayer else { return }
        
        // Animate the press state
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        
        if isPressed {
            // Darken the button when pressed (reduce opacity to 0.7)
            backgroundLayer.opacity = 0.7
            // Also slightly scale down for visual feedback
            layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1.0)
        } else {
            // Restore normal appearance
            backgroundLayer.opacity = 1.0
            layer?.transform = CATransform3DIdentity
        }
        
        CATransaction.commit()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

