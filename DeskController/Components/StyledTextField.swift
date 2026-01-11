//
//  StyledTextField.swift
//  DeskController
//
//  Reusable styled text field component
//

import SwiftUI

struct StyledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: DesignConstants.Typography.labelSize))
                .foregroundColor(DesignConstants.Colors.textMuted)

            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(DesignConstants.Colors.inputBackground)
                .foregroundColor(.white)
                .cornerRadius(DesignConstants.Styling.inputCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.Styling.inputCornerRadius)
                        .stroke(DesignConstants.Colors.border, lineWidth: DesignConstants.Styling.standardBorderWidth)
                )
        }
    }
}

struct StyledNumberField: View {
    let label: String
    let placeholder: String
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: DesignConstants.Typography.labelSize))
                .foregroundColor(DesignConstants.Colors.textMuted)

            TextField(placeholder, text: $value)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(DesignConstants.Colors.inputBackground)
                .foregroundColor(.white)
                .cornerRadius(DesignConstants.Styling.inputCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.Styling.inputCornerRadius)
                        .stroke(DesignConstants.Colors.border, lineWidth: DesignConstants.Styling.standardBorderWidth)
                )
        }
    }
}
