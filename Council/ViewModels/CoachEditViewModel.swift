import SwiftUI
import FirebaseAuth

@MainActor
class CoachEditViewModel: ObservableObject {
    @Published var name: String
    @Published var category: CoachCategory
    @Published var orbColors: [String]
    @Published var selectedVoiceId: String
    @Published var selectedVoiceName: String
    @Published var speechSpeed: Double
    @Published var responsePace: CoachResponsePace
    @Published var quickReplies: Bool
    @Published var expressiveStyle: CoachExpressiveStyle
    @Published var enabledMCPServiceTypes: Set<String>
    @Published var connectedServices: [ConnectedService]
    @Published var isSaving = false
    @Published var saveSuccess = false
    @Published var error: String?
    @Published var availableVoices: [VoiceOption] = []
    @Published var isLoadingVoices = false

    let coach: Coach
    let config: UserCoachConfig?

    private let originalName: String
    private let originalCategory: CoachCategory
    private let originalOrbColors: [String]
    private let originalVoiceId: String
    private let originalSpeechSpeed: Double
    private let originalResponsePace: CoachResponsePace
    private let originalQuickReplies: Bool
    private let originalExpressiveStyle: CoachExpressiveStyle
    private let originalMCPTypes: Set<String>

    init(coach: Coach, config: UserCoachConfig?, connectedServices: [ConnectedService]) {
        self.coach = coach
        self.config = config
        self.connectedServices = connectedServices

        let resolvedName = config?.customName ?? coach.name
        let resolvedCategory = CoachCategory(rawValue: config?.customCategory ?? coach.category.rawValue) ?? coach.category
        let resolvedColors = config?.customOrbColors ?? coach.orbColors
        let resolvedVoiceId = config?.customVoiceId ?? coach.voiceId
        let resolvedVoiceName = config?.customVoiceName ?? coach.voiceName
        let resolvedSpeechSpeed = config?.customSpeechSpeed ?? coach.speechSpeed
        let resolvedResponsePace = CoachResponsePace(
            rawValue: config?.customResponsePace ?? coach.responsePace.rawValue
        ) ?? coach.responsePace
        let resolvedQuickReplies = config?.customQuickReplies ?? coach.quickReplies
        let resolvedExpressiveStyle = CoachExpressiveStyle(
            rawValue: config?.customExpressiveStyle ?? coach.expressiveStyle.rawValue
        ) ?? coach.expressiveStyle
        let resolvedMCPTypes = Set(config?.enabledMCPServiceTypes ?? [])

        self.name = resolvedName
        self.category = resolvedCategory
        self.orbColors = resolvedColors
        self.selectedVoiceId = resolvedVoiceId
        self.selectedVoiceName = resolvedVoiceName
        self.speechSpeed = resolvedSpeechSpeed
        self.responsePace = resolvedResponsePace
        self.quickReplies = resolvedQuickReplies
        self.expressiveStyle = resolvedExpressiveStyle
        self.enabledMCPServiceTypes = resolvedMCPTypes

        self.originalName = resolvedName
        self.originalCategory = resolvedCategory
        self.originalOrbColors = resolvedColors
        self.originalVoiceId = resolvedVoiceId
        self.originalSpeechSpeed = resolvedSpeechSpeed
        self.originalResponsePace = resolvedResponsePace
        self.originalQuickReplies = resolvedQuickReplies
        self.originalExpressiveStyle = resolvedExpressiveStyle
        self.originalMCPTypes = resolvedMCPTypes
    }

    var hasChanges: Bool {
        name != originalName ||
        category != originalCategory ||
        orbColors != originalOrbColors ||
        selectedVoiceId != originalVoiceId ||
        abs(speechSpeed - originalSpeechSpeed) > 0.0001 ||
        responsePace != originalResponsePace ||
        quickReplies != originalQuickReplies ||
        expressiveStyle != originalExpressiveStyle ||
        enabledMCPServiceTypes != originalMCPTypes
    }

    var orbColorPair: (Color, Color) {
        guard orbColors.count >= 2 else {
            return AppColors.orbPalettes[0]
        }
        return (Color(hex: orbColors[0]), Color(hex: orbColors[1]))
    }

    func isServiceConnected(_ type: ServiceType) -> Bool {
        connectedServices.first { $0.serviceType == type }?.isConnected ?? false
    }

    func toggleMCP(serviceType: ServiceType) {
        let key = serviceType.rawValue
        if enabledMCPServiceTypes.contains(key) {
            enabledMCPServiceTypes.remove(key)
        } else {
            enabledMCPServiceTypes.insert(key)
        }
    }

    func isMCPEnabled(_ type: ServiceType) -> Bool {
        enabledMCPServiceTypes.contains(type.rawValue)
    }

    func loadVoices() async {
        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            availableVoices = try await ElevenLabsAPIService.shared.listVoices()
        } catch {
            self.error = "Failed to load voices: \(error.localizedDescription)"
        }
    }

    func save() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            // Ensure we have a cloned agent
            var agentId = config?.clonedAgentId ?? ""

            if agentId.isEmpty {
                // Clone agent on first edit
                agentId = try await ElevenLabsAPIService.shared.cloneAgent(
                    name: "\(name)",
                    systemPrompt: coach.systemPrompt,
                    firstMessage: coach.firstMessage,
                    voiceId: selectedVoiceId,
                    llmModel: coach.llmModel.rawValue,
                    speechSpeed: speechSpeed,
                    responsePace: responsePace,
                    quickReplies: quickReplies,
                    expressiveStyle: expressiveStyle
                )
            }

            // Update agent settings if changed
            if selectedVoiceId != originalVoiceId ||
                abs(speechSpeed - originalSpeechSpeed) > 0.0001 ||
                responsePace != originalResponsePace ||
                quickReplies != originalQuickReplies ||
                expressiveStyle != originalExpressiveStyle {
                try await ElevenLabsAPIService.shared.updateAgent(
                    agentId: agentId,
                    voiceId: selectedVoiceId,
                    speechSpeed: speechSpeed,
                    responsePace: responsePace,
                    quickReplies: quickReplies,
                    expressiveStyle: expressiveStyle
                )
            }

            // Update MCP attachments if changed
            if enabledMCPServiceTypes != originalMCPTypes {
                let mcpServerIds = enabledMCPServiceTypes.compactMap { typeRaw -> String? in
                    guard let type = ServiceType(rawValue: typeRaw) else { return nil }
                    return connectedServices.first { $0.serviceType == type }?.mcpServerId
                }
                try await ElevenLabsAPIService.shared.updateAgentMCP(
                    agentId: agentId,
                    mcpServerIds: mcpServerIds
                )
            }

            // Save config to Firestore
            let updatedConfig = UserCoachConfig(
                id: coach.id,
                userId: userId,
                sourceCoachId: coach.id,
                clonedAgentId: agentId,
                enabledMCPServiceTypes: Array(enabledMCPServiceTypes),
                customName: name != coach.name ? name : nil,
                customCategory: category != coach.category ? category.rawValue : nil,
                customOrbColors: orbColors != coach.orbColors ? orbColors : nil,
                customVoiceId: selectedVoiceId != coach.voiceId ? selectedVoiceId : nil,
                customVoiceName: selectedVoiceName != coach.voiceName ? selectedVoiceName : nil,
                customSpeechSpeed: abs(speechSpeed - coach.speechSpeed) > 0.0001 ? speechSpeed : nil,
                customResponsePace: responsePace != coach.responsePace ? responsePace.rawValue : nil,
                customQuickReplies: quickReplies != coach.quickReplies ? quickReplies : nil,
                customExpressiveStyle: expressiveStyle != coach.expressiveStyle ? expressiveStyle.rawValue : nil,
                createdAt: config?.createdAt ?? Date(),
                updatedAt: Date()
            )
            try await FirebaseService.shared.saveCoachConfig(userId: userId, config: updatedConfig)

            saveSuccess = true
        } catch {
            print("❌ CoachEdit save error: \(error)")
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }
}
