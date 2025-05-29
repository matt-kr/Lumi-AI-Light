import SwiftData
import Foundation

@Model
final class ConversationSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var lastModifiedTime: Date
    var isPinned: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageModel.conversation)
    var messages: [ChatMessageModel] = [] // Non-optional, initialized

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm" // Using startTime
        return formatter.string(from: lastModifiedTime)
    }
    
    // Summary title using startTime
    var summaryTitle: String {
        if let firstUserMessage = messages.first(where: { $0.senderTypeValue == SenderType.user.rawValue }) {
            let words = firstUserMessage.text.split(separator: " ")
            let summary = words.prefix(5).joined(separator: " ")
            return summary.isEmpty ? title : summary + (words.count > 5 ? "..." : "")
        }
        return title
    }

    init(id: UUID = UUID(),
             startTime: Date = Date(),
             lastModifiedTime: Date? = nil, // Allow optional for flexibility
             messages: [ChatMessageModel] = [],
             isPinned: Bool = false) {     // <<<< 2. ADD isPinned to init
            self.id = id
            self.startTime = startTime
            self.lastModifiedTime = lastModifiedTime ?? startTime // Default to startTime if not provided
            self.messages = messages
            self.isPinned = isPinned 
    }
}
