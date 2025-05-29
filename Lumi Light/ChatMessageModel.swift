import SwiftData
import Foundation

// Helper enum for storing the 'type' in SwiftData
enum SenderType: String, Codable {
    case user
    case lumi
    case error
    case info
}

@Model
final class ChatMessageModel {
    @Attribute(.unique) var id: UUID // Was 'var' for Swift 6 mode
    var senderTypeValue: String
    var isErrorCritical: Bool?
    var text: String
    var timestamp: Date
    var conversation: ConversationSession?

    // Full 'sender' computed property
    var sender: Sender { // 'Sender' MUST be your original enum type from ChatMessage.swift
        get {
            guard let type = SenderType(rawValue: senderTypeValue) else { return .info }
            switch type {
            case .user: return .user
            case .lumi: return .lumi
            case .info: return .info
            case .error: return .error(isCritical: isErrorCritical ?? false)
            }
        }
        set {
            switch newValue {
            case .user: senderTypeValue = SenderType.user.rawValue; isErrorCritical = nil
            case .lumi: senderTypeValue = SenderType.lumi.rawValue; isErrorCritical = nil
            case .info: senderTypeValue = SenderType.info.rawValue; isErrorCritical = nil
            case .error(let critical):
                senderTypeValue = SenderType.error.rawValue
                isErrorCritical = critical
            }
        }
    }

    // Initializer to convert from your original ChatMessage struct
    init(from original: ChatMessage) { // 'ChatMessage' MUST be your original struct type
        self.id = original.id
        self.text = original.text
        self.timestamp = original.timestamp
        self.senderTypeValue = ""
        self.isErrorCritical = nil
        self.sender = original.sender // This uses the setter
    }
    
    // Initializer for creating a brand new ChatMessageModel directly
    init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.senderTypeValue = ""
        self.isErrorCritical = nil
        self.sender = sender
    }
}
