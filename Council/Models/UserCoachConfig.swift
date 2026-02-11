import Foundation

struct UserCoachConfig: Codable, Identifiable {
    var id: String                      // = sourceCoachId
    var userId: String
    var sourceCoachId: String
    var clonedAgentId: String
    var enabledMCPServiceTypes: [String] // e.g. ["notion"]
    var customName: String?
    var customCategory: String?
    var customOrbColors: [String]?
    var customVoiceId: String?
    var customVoiceName: String?
    var customSpeechSpeed: Double?
    var customResponsePace: String?
    var customQuickReplies: Bool?
    var customExpressiveStyle: String?
    var createdAt: Date
    var updatedAt: Date
}
