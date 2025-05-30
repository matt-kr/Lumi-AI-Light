import SwiftData
import Foundation

@Model
final class ConversationSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var lastModifiedTime: Date
    var isPinned: Bool = false
    var customTitle: String?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageModel.conversation)
    var messages: [ChatMessageModel] = [] // Non-optional, initialized

    var title: String {
        // Prioritize customTitle if it exists and is not just whitespace
        if let userTitle = customTitle, !userTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return userTitle
        }
        
        // Default title format using lastModifiedTime
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm" // User preference: No year
        return formatter.string(from: lastModifiedTime)
    }
    
    // Summary title will use the 'title' property, so it reflects custom or date-based title
    var summaryTitle: String {
        if let firstUserMessage = messages.first(where: { $0.senderTypeValue == SenderType.user.rawValue }) {
            let words = firstUserMessage.text.split(separator: " ")
            let summary = words.prefix(5).joined(separator: " ")
            // Uses self.title, which will be custom or date-based
            return summary.isEmpty ? self.title : summary + (words.count > 5 ? "..." : "")
        }
        return self.title // Fallback to full title if no user message or empty summary
    }

    init(id: UUID = UUID(),
         startTime: Date = Date(),
         lastModifiedTime: Date? = nil,
         messages: [ChatMessageModel] = [],
         isPinned: Bool = false,
         customTitle: String? = nil) {
            self.id = id
            self.startTime = startTime
            self.lastModifiedTime = lastModifiedTime ?? startTime // Default to startTime if not provided
            self.messages = messages
            self.isPinned = isPinned
            self.customTitle = customTitle
    }
}
