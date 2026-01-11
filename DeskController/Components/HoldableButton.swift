//
//  HoldableButton.swift
//  DeskController
//
//  Holdable button component for continuous desk movement
//

import SwiftUI
import AppKit

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
        layer?.cornerRadius = DesignConstants.Styling.buttonCornerRadius

        // Background layer
        backgroundLayer = CALayer()
        backgroundLayer?.cornerRadius = DesignConstants.Styling.buttonCornerRadius
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
