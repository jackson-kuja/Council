import Foundation

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case notion

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notion: return "Notion"
        }
    }

    var icon: String {
        switch self {
        case .notion: return "doc.text.fill"
        }
    }

    var mcpEndpoint: String {
        switch self {
        case .notion: return "https://notion-mcp-proxy-595176568496.us-central1.run.app/mcp"
        }
    }

    var oauthAuthorizeURL: String {
        switch self {
        case .notion: return "https://api.notion.com/v1/oauth/authorize"
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
