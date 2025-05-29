import SwiftData
import Foundation

@Model
final class ConversationSession {
    @Attribute(.unique) let id: UUID
    var startTime: Date

    // Relationship: One session has many messages.
    // .cascade means delete messages if session is deleted.
    @Relationship(deleteRule: .cascade, inverse: \ChatMessageModel.conversation)
    var messages: [ChatMessageModel]? = []

    // Computed property for the Date/Time title
    var title: String {
        startTime.formatted(date: .abbreviated, time: .shortened)
    }
    
    // Computed property for a potential summary title (basic - first user message)
    var summaryTitle: String {
        if let firstUserMessage = messages?.first(where: { $0.senderTypeValue == SenderType.user.rawValue }) {
            let words = firstUserMessage.text.split(separator: " ")
            let summary = words.prefix(5).joined(separator: " ")
            return summary.isEmpty ? title : summary + (words.count > 5 ? "..." : "")
        }
        return title // Fallback to date/time title
    }

    init(startTime: Date = Date(), messages: [ChatMessageModel] = []) {
        self.id = UUID()
        self.startTime = startTime
        self.messages = messages
    }
}