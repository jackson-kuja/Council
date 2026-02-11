import Foundation

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case notion
    case googleCalendar
    case todoist
    case appleReminders

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notion: return "Notion"
        case .googleCalendar: return "Google Calendar"
        case .todoist: return "Todoist"
        case .appleReminders: return "Reminders"
        }
    }

    var icon: String {
        switch self {
        case .notion: return "doc.text.fill"
        case .googleCalendar: return "calendar"
        case .todoist: return "checkmark.circle.fill"
        case .appleReminders: return "list.bullet.circle.fill"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .notion: return true
        case .googleCalendar, .todoist, .appleReminders: return false
        }
    }

    var mcpEndpoint: String {
        switch self {
        case .notion: return "https://notion-mcp-proxy-595176568496.us-central1.run.app/mcp"
        case .googleCalendar, .todoist, .appleReminders: return ""
        }
    }

    var oauthAuthorizeURL: String {
        switch self {
        case .notion: return "https://api.notion.com/v1/oauth/authorize"
        case .googleCalendar, .todoist, .appleReminders: return ""
        }
    }
}

struct ConnectedService: Codable, Identifiable {
    var id: String                  // ServiceType.rawValue
    var serviceType: ServiceType
    var isConnected: Bool
    var connectedAt: Date?
    var mcpServerId: String?        // ElevenLabs MCP server ID
    var workspaceName: String?      // e.g. Notion workspace name
}
