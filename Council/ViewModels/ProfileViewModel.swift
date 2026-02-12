import SwiftUI
import FirebaseAuth

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile = .empty
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var saveSuccess = false

    // Editing fields
    @Published var editingValues: [String] = []
    @Published var editingGoals: [String] = []
    @Published var editingNotes: String = ""
    @Published var newValue: String = ""
    @Published var newGoal: String = ""

    // Connected Services
    @Published var connectedServices: [ConnectedService] = []
    @Published var isConnectingService = false

    func loadProfile() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if let profile = try await FirebaseService.shared.fetchUserProfile(userId: userId) {
                self.profile = profile
                self.editingValues = profile.personalContext.values
                self.editingGoals = profile.personalContext.goals
                self.editingNotes = profile.personalContext.notes
            } else {
                // Create initial profile
                let user = Auth.auth().currentUser
                self.profile = UserProfile(
                    id: userId,
                    displayName: user?.displayName ?? "",
                    email: user?.email ?? "",
                    photoURL: user?.photoURL?.absoluteString,
                    personalContext: .empty,
                    createdAt: Date()
                )
                try await FirebaseService.shared.saveUserProfile(self.profile)
            }

            // Load connected services
            connectedServices = try await FirebaseService.shared.fetchConnectedServices(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func connectedService(for type: ServiceType) -> ConnectedService? {
        connectedServices.first { $0.serviceType == type }
    }

    func connectNotion() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isConnectingService = true
        defer { isConnectingService = false }

        do {
            // 1. OAuth flow
            let (accessToken, workspaceId, workspaceName) = try await NotionOAuthService.shared.startOAuthFlow()

            // 2. Register MCP server in ElevenLabs
            let mcpServerId = try await ElevenLabsAPIService.shared.registerMCPServer(
                name: "Notion - \(profile.displayName)",
                mcpUrl: ServiceType.notion.mcpEndpoint,
                authToken: accessToken
            )

            // 3. Save to Firestore
            let service = ConnectedService(
                id: ServiceType.notion.rawValue,
                serviceType: .notion,
                isConnected: true,
                connectedAt: Date(),
                mcpServerId: mcpServerId,
                workspaceName: workspaceName
            )
            try await FirebaseService.shared.saveConnectedService(userId: userId, service: service)

            // 4. Update local state
            if let index = connectedServices.firstIndex(where: { $0.serviceType == .notion }) {
                connectedServices[index] = service
            } else {
                connectedServices.append(service)
            }
        } catch {
            print("❌ connectNotion error: \(error)")
            self.error = "Failed to connect Notion: \(error.localizedDescription)"
        }
    }

    func disconnectService(_ type: ServiceType) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let service = connectedService(for: type), service.isConnected else { return }

        do {
            // 1. Detach MCP server from all agents that use it
            if let mcpServerId = service.mcpServerId {
                let configs = try await FirebaseService.shared.fetchAllCoachConfigs(userId: userId)
                for config in configs where config.enabledMCPServiceTypes.contains(type.rawValue) {
                    try await ElevenLabsAPIService.shared.updateAgentMCP(
                        agentId: config.clonedAgentId,
                        mcpServerIds: []
                    )
                }

                // 2. Delete MCP server from ElevenLabs
                try await ElevenLabsAPIService.shared.deleteMCPServer(mcpServerId: mcpServerId)
            }

            // 3. Remove service type from all coach configs
            try await FirebaseService.shared.removeServiceFromAllConfigs(
                userId: userId, serviceType: type.rawValue
            )

            // 4. Delete from Firestore
            try await FirebaseService.shared.deleteConnectedService(userId: userId, serviceType: type.rawValue)

            // 5. Update local state
            connectedServices.removeAll { $0.serviceType == type }
        } catch {
            self.error = "Failed to disconnect \(type.displayName): \(error.localizedDescription)"
        }
    }

    func addValue() {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        editingValues.append(trimmed)
        newValue = ""
    }

    func removeValue(at index: Int) {
        editingValues.remove(at: index)
    }

    func addGoal() {
        let trimmed = newGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        editingGoals.append(trimmed)
        newGoal = ""
    }

    func removeGoal(at index: Int) {
        editingGoals.remove(at: index)
    }

    func saveContext() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        saveSuccess = false
        defer { isSaving = false }

        let context = PersonalContext(
            values: editingValues,
            goals: editingGoals,
            notes: editingNotes
        )

        do {
            try await FirebaseService.shared.updatePersonalContext(userId: userId, context: context)
            profile.personalContext = context
            saveSuccess = true

            // Auto-dismiss success after 2s
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                saveSuccess = false
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
