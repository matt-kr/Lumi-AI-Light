//import SwiftUI

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
                //    .font(.caption2)
                //    .foregroundColor(Color.sl_textSecondary)
                //    .padding(.horizontal, 5)
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
//  MessageView.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/11/25.
//

import Foundation
import SwiftUICore
