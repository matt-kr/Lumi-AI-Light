import SwiftData
import Foundation

@Model
final class ConversationSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    // var lastModifiedTime: Date // <<<< We'll add this back later

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageModel.conversation)
    var messages: [ChatMessageModel] = [] // Non-optional, initialized

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm" // Using startTime
        return formatter.string(from: startTime)
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

    init(startTime: Date = Date(), messages: [ChatMessageModel] = []) {
        self.id = UUID()
        self.startTime = startTime
        // self.lastModifiedTime = startTime // No lastModifiedTime yet
        self.messages = messages
    }
}
