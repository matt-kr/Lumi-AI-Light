import Foundation

enum Sender: Equatable {
    case user
    case lumi
    case error(isCritical: Bool = false)
    case info
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var sender: Sender
    var text: String
    let timestamp: Date

    init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.sender == rhs.sender
    }
}
