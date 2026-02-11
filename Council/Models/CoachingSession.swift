import Foundation

struct CoachingSession: Identifiable, Codable {
    var id: String
    var userId: String
    var coachId: String
    var coachName: String
    var additionalCoachIds: [String] = []
    var additionalCoachNames: [String] = []
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
    var elevenlabsConversationId: String?
    var transcript: [TranscriptMessage]

    var formattedDuration: String {
        guard let duration = durationSeconds else { return "--" }
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }
}

struct TranscriptMessage: Identifiable, Codable {
    var id: String
    var role: MessageRole
    var content: String
    var timestamp: Date
    var coachId: String?
    var coachName: String?

    init(id: String = UUID().uuidString, role: MessageRole, content: String, timestamp: Date = Date(), coachId: String? = nil, coachName: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.coachId = coachId
        self.coachName = coachName
    }
}

enum MessageRole: String, Codable {
    case user
    case agent
}
