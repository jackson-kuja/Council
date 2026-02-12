import Foundation
import FirebaseFunctions

class ElevenLabsAPIService {
    static let shared = ElevenLabsAPIService()
    private let functions = Functions.functions()

    private init() {}

    /// Creates an ElevenLabs agent via Cloud Function and returns the agent ID
    func createAgent(
        name: String,
        systemPrompt: String,
        firstMessage: String,
        voiceId: String,
        llmModel: String,
        speechSpeed: Double,
        responsePace: CoachResponsePace,
        quickReplies: Bool,
        expressiveStyle: CoachExpressiveStyle
    ) async throws -> String {
        let data: [String: Any] = [
            "name": name,
            "systemPrompt": systemPrompt,
            "firstMessage": firstMessage,
            "voiceId": voiceId,
            "llmModel": llmModel,
            "speechSpeed": speechSpeed,
            "responsePace": responsePace.rawValue,
            "quickReplies": quickReplies,
            "expressiveStyle": expressiveStyle.rawValue,
        ]

        let result = try await functions.httpsCallable("createAgent").call(data)

        guard let data = result.data as? [String: Any],
              let agentId = data["agentId"] as? String else {
            throw ElevenLabsError.invalidResponse
        }
        return agentId
    }

    /// Deletes an ElevenLabs agent via Cloud Function
    func deleteAgent(agentId: String) async throws {
        _ = try await functions.httpsCallable("deleteAgent").call([
            "agentId": agentId,
        ])
    }

    /// Updates an ElevenLabs agent's configuration via Cloud Function
    func updateAgent(
        agentId: String,
        llmModel: String? = nil,
        systemPrompt: String? = nil,
        firstMessage: String? = nil,
        voiceId: String? = nil,
        speechSpeed: Double? = nil,
        responsePace: CoachResponsePace? = nil,
        quickReplies: Bool? = nil,
        expressiveStyle: CoachExpressiveStyle? = nil
    ) async throws {
        var data: [String: Any] = ["agentId": agentId]
        if let llmModel { data["llmModel"] = llmModel }
        if let systemPrompt { data["systemPrompt"] = systemPrompt }
        if let firstMessage { data["firstMessage"] = firstMessage }
        if let voiceId { data["voiceId"] = voiceId }
        if let speechSpeed { data["speechSpeed"] = speechSpeed }
        if let responsePace { data["responsePace"] = responsePace.rawValue }
        if let quickReplies { data["quickReplies"] = quickReplies }
        if let expressiveStyle { data["expressiveStyle"] = expressiveStyle.rawValue }

        _ = try await functions.httpsCallable("updateAgent").call(data)
    }

    /// Updates an ElevenLabs agent's TTS configuration for multi-voice support
    func updateAgentMultiVoice(
        agentId: String,
        supportedVoices: [SupportedVoice]
    ) async throws {
        let voicesData: [[String: Any]] = supportedVoices.map { voice in
            [
                "voiceId": voice.voiceId,
                "label": voice.label,
                "description": voice.description,
            ]
        }

        let data: [String: Any] = [
            "agentId": agentId,
            "supportedVoices": voicesData,
        ]

        _ = try await functions.httpsCallable("updateAgentMultiVoice").call(data)
    }

    /// Clones an ElevenLabs agent (reuses createAgent Cloud Function) and returns the new agent ID
    func cloneAgent(
        name: String,
        systemPrompt: String,
        firstMessage: String,
        voiceId: String,
        llmModel: String,
        speechSpeed: Double,
        responsePace: CoachResponsePace,
        quickReplies: Bool,
        expressiveStyle: CoachExpressiveStyle
    ) async throws -> String {
        try await createAgent(
            name: name,
            systemPrompt: systemPrompt,
            firstMessage: firstMessage,
            voiceId: voiceId,
            llmModel: llmModel,
            speechSpeed: speechSpeed,
            responsePace: responsePace,
            quickReplies: quickReplies,
            expressiveStyle: expressiveStyle
        )
    }

    /// Registers an MCP server in the ElevenLabs workspace via Cloud Function
    func registerMCPServer(name: String, mcpUrl: String, authToken: String) async throws -> String {
        let result = try await functions.httpsCallable("registerMCPServer").call([
            "name": name,
            "mcpUrl": mcpUrl,
            "authToken": authToken,
        ])

        guard let data = result.data as? [String: Any],
              let mcpServerId = data["mcpServerId"] as? String else {
            throw ElevenLabsError.invalidResponse
        }
        return mcpServerId
    }

    /// Updates the MCP servers attached to an ElevenLabs agent
    func updateAgentMCP(agentId: String, mcpServerIds: [String]) async throws {
        _ = try await functions.httpsCallable("updateAgentMCP").call([
            "agentId": agentId,
            "mcpServerIds": mcpServerIds,
        ])
    }

    /// Deletes an MCP server registration from ElevenLabs
    func deleteMCPServer(mcpServerId: String) async throws {
        _ = try await functions.httpsCallable("deleteMCPServer").call([
            "mcpServerId": mcpServerId,
        ])
    }

    /// Exchanges a Notion OAuth authorization code for an access token via Cloud Function
    func exchangeNotionOAuth(code: String, redirectUri: String) async throws -> (accessToken: String, workspaceId: String, workspaceName: String) {
        let result = try await functions.httpsCallable("exchangeNotionOAuth").call([
            "code": code,
            "redirectUri": redirectUri,
        ])

        guard let data = result.data as? [String: Any],
              let accessToken = data["accessToken"] as? String else {
            throw ElevenLabsError.invalidResponse
        }
        return (
            accessToken: accessToken,
            workspaceId: data["workspaceId"] as? String ?? "",
            workspaceName: data["workspaceName"] as? String ?? ""
        )
    }

    /// Lists available voices via Cloud Function (proxied to avoid exposing API key)
    func listVoices() async throws -> [VoiceOption] {
        let result = try await functions.httpsCallable("listVoices").call([:])

        guard let data = result.data as? [String: Any],
              let voicesData = data["voices"] as? [[String: Any]] else {
            throw ElevenLabsError.invalidResponse
        }

        return voicesData.compactMap { voice in
            guard let id = voice["voice_id"] as? String,
                  let name = voice["name"] as? String,
                  let previewUrl = voice["preview_url"] as? String,
                  !previewUrl.isEmpty,
                  URL(string: previewUrl) != nil else { return nil }
            return VoiceOption(
                id: id,
                name: name,
                category: voice["category"] as? String ?? "premade",
                previewUrl: previewUrl,
                labels: voice["labels"] as? [String: String] ?? [:]
            )
        }
    }
}

struct SupportedVoice {
    let voiceId: String
    let label: String
    let description: String
}

struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let previewUrl: String?
    let labels: [String: String]

    var accent: String? { labels["accent"] }
    var gender: String? { labels["gender"] }
    var age: String? { labels["age"] }
    var descriptive: String? { labels["descriptive"] }
}

enum ElevenLabsError: LocalizedError {
    case invalidResponse
    case agentCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .agentCreationFailed(let msg): return "Failed to create agent: \(msg)"
        }
    }
}
