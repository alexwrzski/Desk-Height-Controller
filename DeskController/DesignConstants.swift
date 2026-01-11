//
//  DesignConstants.swift
//  DeskController
//
//  Centralized design system for consistent styling
//

import SwiftUI

enum DesignConstants {

    // MARK: - Colors

    enum Colors {
        // Primary Colors
        static let background = Color(hex: "1a1a1a")          // Main app background
        static let cardBackground = Color(hex: "262626")      // Card/section background
        static let accentBlue = Color(hex: "3b82f6")          // Primary accent color
        static let successGreen = Color(hex: "4ade80")        // Success/connected state
        static let errorRed = Color(hex: "f87171")            // Error/disconnected state
        static let warningYellow = Color(hex: "fbbf24")       // Warning state

        // Text Colors
        static let textMuted = Color(hex: "888888")           // Muted/secondary text
        static let textDimmed = Color(hex: "666666")          // Dimmed text

        // Background Variations
        static let inputBackground = Color(hex: "111111")     // Text input background
        static let buttonBackground = Color(hex: "333333")    // Button background
        static let presetButtonBackground = Color(hex: "3f3f3f") // Preset button background
        static let errorBackground = Color(hex: "422222")     // Error message background

        // Borders
        static let border = Color(hex: "444444")              // Standard border
        static let borderDashed = Color(hex: "555555")        // Dashed border
    }

    // MARK: - Layout

    enum Layout {
        // Window
        static let windowWidth: CGFloat = 300
        static let windowMinHeight: CGFloat = 500
        static let windowTopPadding: CGFloat = 10

        // Section Heights
        static let headerHeight: CGFloat = 110                // Header section (Current Height + status)
        static let controlsHeight: CGFloat = 218              // Main controls card
        static let presetSectionHeader: CGFloat = 30          // "QUICK PRESETS" label
        static let presetButtonHeight: CGFloat = 40           // Height of each preset button
        static let settingsButtonHeight: CGFloat = 95         // Settings button + bottom padding

        // Spacing
        static let presetSpacing: CGFloat = 8                 // Spacing between preset buttons
        static let cardPadding: CGFloat = 18                  // Card internal padding
        static let sectionSpacing: CGFloat = 12               // Spacing between sections
    }

    // MARK: - Typography

    enum Typography {
        // Font Sizes
        static let heightDisplaySize: CGFloat = 48           // Current height display
        static let statusSize: CGFloat = 12                  // Status text
        static let labelSize: CGFloat = 11                   // Small labels
        static let buttonSize: CGFloat = 14                  // Button text
        static let presetButtonSize: CGFloat = 13            // Preset button text

        // Font Weights
        static let heightDisplayWeight: Font.Weight = .bold
        static let buttonWeight: Font.Weight = .semibold
    }

    // MARK: - Styling

    enum Styling {
        // Corner Radius
        static let cardCornerRadius: CGFloat = 12
        static let buttonCornerRadius: CGFloat = 10
        static let inputCornerRadius: CGFloat = 6
        static let presetCornerRadius: CGFloat = 8

        // Border Width
        static let standardBorderWidth: CGFloat = 1
    }
}
