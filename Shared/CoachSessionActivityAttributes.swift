import Foundation
import ActivityKit

struct CoachSessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var statusLabel: String
        var isMuted: Bool
        var isConnected: Bool
        var startedAt: Date
        var elapsedSeconds: Int
    }

    var sessionId: String
    var coachName: String
    var primaryColorHex: String
    var secondaryColorHex: String
}
