import SwiftUI
import Foundation
import SwiftUICore // Assuming this is needed and correctly placed by you

struct MessageView: View {
    let message: ChatMessage
    let nasalizationFont = "Nasalization-Regular"
    let messageFontName = "Trebuchet MS" // Or your preferred message font

    var body: some View {
        HStack(spacing: 0) {
            if message.sender == .user { Spacer(minLength: 40) }

            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                // Optional: Sender Icon and Name (Add images to Assets)
                // if message.sender == .lumi {
                //     HStack {
                //         Image("lumi_icon") // e.g., a small version of your favicon
                //             .resizable().frame(width: 20, height: 20).clipShape(Circle())
                //         Text("Lumi")
                //             .font(.custom(nasalizationFont, size: 12))
                //             .foregroundColor(Color.sl_textSecondary)
                //     }
                // }

                messageContent()
                    .padding(message.sender == .error(isCritical: false) || message.sender == .info ? 8 : 12) // Smaller padding for info/error
                    .background(backgroundColorForSender(message.sender))
                    .cornerRadius(12)
                    .shadow(color: shadowColorForSender(message.sender), radius: 2, x: 1, y: 1) // Subtle shadow for depth
                
                // Optional: Timestamp
                // Text(message.timestamp, style: .time)
                //     .font(.caption2)
                //     .foregroundColor(Color.sl_textSecondary)
                //     .padding(.horizontal, 5)
            }
            .fixedSize(horizontal: false, vertical: true) // Important for text wrapping

            if message.sender != .user { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private func messageContent() -> some View {
        Text(message.text)
            .font(.custom(messageFontName, size: 16))
            .foregroundColor(textColorForSender(message.sender))
            .lineSpacing(3)
            // --- ADD THIS MODIFIER FOR TEXT SELECTION ---
            .textSelection(.enabled)
            // --- END ADD ---
    }

    private func backgroundColorForSender(_ sender: Sender) -> Color {
        switch sender {
        case .user: return Color.sl_bgUserMessage
        case .lumi: return Color.sl_bgLumiMessage
        case .error(let isCritical): return isCritical ? Color.sl_errorBg : Color.sl_errorBg.opacity(0.8)
        case .info: return Color.sl_bgSecondary // Or a distinct info background
        }
    }
    
    private func textColorForSender(_ sender: Sender) -> Color {
        switch sender {
        case .error: return Color.sl_errorText
        default: return Color.sl_textPrimary
        }
    }

    private func shadowColorForSender(_ sender: Sender) -> Color {
        switch sender {
        case .user, .lumi: return Color.black.opacity(0.2)
        default: return Color.clear
        }
    }
}

// Preview - Use this block if you want to preview MessageView.
// Ensure your ChatMessage and Sender types are accessible.
#Preview {
    // This preview assumes:
    // 1. Your 'ChatMessage' struct/class can be initialized with (sender: Sender, text: String)
    //    (and handles its 'id' internally).
    // 2. Your 'Sender' enum is accessible and has .user and .lumi cases.
    // 3. Your 'Color.sl_bgPrimary' is defined and accessible.

    VStack {
        MessageView(message: ChatMessage(sender: .user, text: "This is a user message you can try to select."))
        MessageView(message: ChatMessage(sender: .lumi, text: "This is Lumi's response. Try long-pressing me!"))
    }
    .padding()
    .background(Color.sl_bgPrimary)
    .preferredColorScheme(.dark)
    // If ChatMessage or other dependencies (like UserData for colors, though not directly used here)
    // are needed for your actual types, add them as environmentObjects if necessary.
    // .environmentObject(UserData.shared)
}

// The comments below "// MessageView.swift", "// Lumi Light", etc.
// and the "import Foundation" and "import SwiftUICore" that were at the bottom
// of your pasted code should remain where they were in your original file structure,
// or ideally, all imports should be at the top.
// The code above reflects having all imports at the top.
