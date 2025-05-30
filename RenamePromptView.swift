import SwiftUI
import SwiftData // Needed for @Bindable with ConversationSession
import Foundation

struct RenamePromptView: View {
    @Bindable var sessionToRename: ConversationSession // The session being renamed
    @State private var currentName: String           // Local state for the TextField
    
    var onSave: () -> Void // Closure to call when save is tapped (for dismissal)
    var onCancel: () -> Void     // Closure to call for dismissal via X or background tap
    
    // Assuming your custom font name
    private let nasalizationFont = "Nasalization-Regular"
    
    init(sessionToRename: ConversationSession, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.sessionToRename = sessionToRename
        // Initialize local state with the session's current custom title or empty
        self._currentName = State(initialValue: sessionToRename.customTitle ?? "")
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    private func hideKeyboardInPrompt() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        VStack(spacing: 15) { // Main VStack for card content
            // "X" button for dismissal - keep it tight to the corner
            HStack {
                Spacer() // Pushes X to the right
                Button {
                    hideKeyboardInPrompt()
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2.weight(.light)) // Made X slightly lighter
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
            // No extra vertical padding around the X button's HStack itself.
            // The VStack's overall padding (defined below) will give it space from card edge.
            
            Text("Rename Chat")
                .font(.custom(nasalizationFont, size: 20))
                .foregroundColor(Color.sl_textPrimary)
            // Let VStack spacing and overall padding handle space before/after title
            
            TextField("Chat name", text: $currentName)
                .font(.custom(nasalizationFont, size: 16))
                .padding(12)
                .background(Color.sl_bgPrimary.opacity(0.5))
                .cornerRadius(10)
                .foregroundColor(Color.sl_textPrimary)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal) // Padding for the text field container
            
            Text("Leave empty to use the default date-based title.")
                .font(.custom(nasalizationFont, size: 12))
                .foregroundColor(Color.sl_textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 5)
            
            Button("Save") { // Only Save button remains from original two-button layout
                hideKeyboardInPrompt()
                // ... (save logic as before) ...
                let trimmedName = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
                sessionToRename.customTitle = trimmedName.isEmpty ? nil : trimmedName
                sessionToRename.lastModifiedTime = Date()
                onSave()
            }
            .font(.custom(nasalizationFont, size: 16))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.sl_bgAccent)
            .foregroundColor(Color.sl_textOnAccent)
            .cornerRadius(10)
            .padding(.horizontal) // Match TextField's horizontal padding
            .padding(.bottom) // Padding after the save button
        }
        // Adjust overall padding, especially .top, for the card content
        .padding(EdgeInsets(top: 15, leading: 20, bottom: 20, trailing: 20)) // Reduced top padding
        .background(.thinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
        .frame(maxWidth: 300) // Keep the constrained width
        // The X button was previously an overlay, I've integrated it into the VStack top.
        // If you prefer the X as an overlay for precise corner placement, we can revert that part.
        // For now, it's an HStack at the top.
    }
    //
    //  RenamePromptView.swift
    //  Lumi Light
    //
    //  Created by Matt Krussow on 5/29/25.
    //
    
}
