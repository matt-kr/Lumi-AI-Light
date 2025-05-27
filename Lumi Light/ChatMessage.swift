import Foundation

enum Sender: Equatable {
    case user
    case lumi
    case error(isCritical: Bool = false) // Critical for non-recoverable, non-critical for stream errors
    case info
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var sender: Sender
    var text: String
    let timestamp: Date = Date()

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.sender == rhs.sender
    }
}
//  ChatMessage.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/11/25.
//

