import Foundation
import FirebaseFirestore

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Coaches

    func fetchFeaturedCoaches() async throws -> [Coach] {
        let snapshot = try await db.collection("coaches")
            .whereField("isFeatured", isEqualTo: true)
            .whereField("isPublic", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try coachFromDocument($0) }
    }

    func fetchCoaches(category: CoachCategory? = nil) async throws -> [Coach] {
        var query: Query = db.collection("coaches")
            .whereField("isPublic", isEqualTo: true)

        if let category = category {
            query = query.whereField("category", isEqualTo: category.rawValue)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try coachFromDocument($0) }
    }

    func fetchCoach(id: String) async throws -> Coach? {
        let doc = try await db.collection("coaches").document(id).getDocument()
        guard doc.exists else { return nil }
        return try coachFromDocument(doc)
    }

    func searchCoaches(query: String) async throws -> [Coach] {
        // Firestore doesn't support full-text search natively.
        // For MVP, fetch all public coaches and filter client-side.
        let allCoaches = try await fetchCoaches()
        let lowered = query.lowercased()
        return allCoaches.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.description.lowercased().contains(lowered) ||
            $0.tags.contains(where: { $0.lowercased().contains(lowered) })
        }
    }

    func createCoach(_ coach: Coach) async throws {
        let data = try encodeToDictionary(coach)
        try await db.collection("coaches").document(coach.id).setData(data)
    }

    func incrementUsageCount(coachId: String) async throws {
        try await db.collection("coaches").document(coachId)
            .updateData(["usageCount": FieldValue.increment(Int64(1))])
    }

    // MARK: - User Profiles

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(userId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return try userProfileFromData(data, id: userId)
    }

    func saveUserProfile(_ profile: UserProfile) async throws {
        let data = try encodeToDictionary(profile)
        try await db.collection("users").document(profile.id).setData(data, merge: true)
    }

    func updatePersonalContext(userId: String, context: PersonalContext) async throws {
        let contextData = try encodeToDictionary(context)
        try await db.collection("users").document(userId)
            .updateData(["personalContext": contextData])
    }

    // MARK: - Sessions

    func saveSession(_ session: CoachingSession) async throws {
        let data = try encodeToDictionary(session)
        try await db.collection("sessions").document(session.id).setData(data)
    }

    func fetchSessions(userId: String) async throws -> [CoachingSession] {
        let snapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startedAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            let data = doc.data()
            return try sessionFromData(data, id: doc.documentID)
        }
    }

    func fetchSessionsForCoach(userId: String, coachId: String) async throws -> [CoachingSession] {
        let snapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .whereField("coachId", isEqualTo: coachId)
            .order(by: "startedAt", descending: false)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try sessionFromData(doc.data(), id: doc.documentID)
        }
    }

    // MARK: - Connected Services

    func fetchConnectedServices(userId: String) async throws -> [ConnectedService] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("connectedServices").getDocuments()
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            return ConnectedService(
                id: doc.documentID,
                serviceType: ServiceType(rawValue: doc.documentID) ?? .notion,
                isConnected: data["isConnected"] as? Bool ?? false,
                connectedAt: (data["connectedAt"] as? Timestamp)?.dateValue(),
                mcpServerId: data["mcpServerId"] as? String,
                workspaceName: data["workspaceName"] as? String
            )
        }
    }

    func saveConnectedService(userId: String, service: ConnectedService) async throws {
        var data: [String: Any] = [
            "id": service.id,
            "serviceType": service.serviceType.rawValue,
            "isConnected": service.isConnected,
        ]
        if let connectedAt = service.connectedAt {
            data["connectedAt"] = Timestamp(date: connectedAt)
        }
        if let mcpServerId = service.mcpServerId {
            data["mcpServerId"] = mcpServerId
        }
        if let workspaceName = service.workspaceName {
            data["workspaceName"] = workspaceName
        }
        try await db.collection("users").document(userId)
            .collection("connectedServices").document(service.id).setData(data)
    }

    func deleteConnectedService(userId: String, serviceType: String) async throws {
        try await db.collection("users").document(userId)
            .collection("connectedServices").document(serviceType).delete()
    }

    // MARK: - Coach Configs

    func fetchCoachConfig(userId: String, sourceCoachId: String) async throws -> UserCoachConfig? {
        let doc = try await db.collection("users").document(userId)
            .collection("coachConfigs").document(sourceCoachId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return coachConfigFromData(data, id: doc.documentID)
    }

    func fetchAllCoachConfigs(userId: String) async throws -> [UserCoachConfig] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("coachConfigs").getDocuments()
        return snapshot.documents.compactMap { doc in
            coachConfigFromData(doc.data(), id: doc.documentID)
        }
    }

    func saveCoachConfig(userId: String, config: UserCoachConfig) async throws {
        var data: [String: Any] = [
            "id": config.id,
            "userId": config.userId,
            "sourceCoachId": config.sourceCoachId,
            "clonedAgentId": config.clonedAgentId,
            "enabledMCPServiceTypes": config.enabledMCPServiceTypes,
            "createdAt": Timestamp(date: config.createdAt),
            "updatedAt": Timestamp(date: config.updatedAt),
        ]
        if let v = config.customName { data["customName"] = v }
        if let v = config.customCategory { data["customCategory"] = v }
        if let v = config.customOrbColors { data["customOrbColors"] = v }
        if let v = config.customVoiceId { data["customVoiceId"] = v }
        if let v = config.customVoiceName { data["customVoiceName"] = v }
        if let v = config.customSpeechSpeed { data["customSpeechSpeed"] = v }
        if let v = config.customResponsePace { data["customResponsePace"] = v }
        if let v = config.customQuickReplies { data["customQuickReplies"] = v }
        if let v = config.customExpressiveStyle { data["customExpressiveStyle"] = v }
        try await db.collection("users").document(userId)
            .collection("coachConfigs").document(config.sourceCoachId).setData(data)
    }

    func deleteCoachConfig(userId: String, sourceCoachId: String) async throws {
        try await db.collection("users").document(userId)
            .collection("coachConfigs").document(sourceCoachId).delete()
    }

    // MARK: - Update MCP on all coach configs

    func removeServiceFromAllConfigs(userId: String, serviceType: String) async throws {
        let configs = try await fetchAllCoachConfigs(userId: userId)
        for var config in configs {
            if config.enabledMCPServiceTypes.contains(serviceType) {
                config.enabledMCPServiceTypes.removeAll { $0 == serviceType }
                config.updatedAt = Date()
                try await saveCoachConfig(userId: userId, config: config)
            }
        }
    }

    // MARK: - Helpers

    private func coachFromDocument(_ doc: DocumentSnapshot) throws -> Coach {
        guard let data = doc.data() else {
            throw NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing document data"])
        }
        return Coach(
            id: doc.documentID,
            name: data["name"] as? String ?? "",
            description: data["description"] as? String ?? "",
            category: CoachCategory(rawValue: data["category"] as? String ?? "custom") ?? .custom,
            systemPrompt: data["systemPrompt"] as? String ?? "",
            firstMessage: data["firstMessage"] as? String ?? "",
            voiceId: data["voiceId"] as? String ?? "",
            voiceName: data["voiceName"] as? String ?? "",
            llmModel: LLMModel(rawValue: data["llmModel"] as? String ?? "gpt-4o") ?? .gpt4o,
            speechSpeed: parsedDouble(data["speechSpeed"], fallback: 1.0),
            responsePace: CoachResponsePace(rawValue: data["responsePace"] as? String ?? "balanced") ?? .balanced,
            quickReplies: data["quickReplies"] as? Bool ?? false,
            expressiveStyle: CoachExpressiveStyle(rawValue: data["expressiveStyle"] as? String ?? "natural") ?? .natural,
            elevenlabsAgentId: data["elevenlabsAgentId"] as? String ?? "",
            creatorId: data["creatorId"] as? String ?? "",
            isPublic: data["isPublic"] as? Bool ?? true,
            tags: data["tags"] as? [String] ?? [],
            usageCount: data["usageCount"] as? Int ?? 0,
            orbColors: data["orbColors"] as? [String] ?? ["CADCFC", "A0B9D1"],
            isFeatured: data["isFeatured"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private func userProfileFromData(_ data: [String: Any], id: String) throws -> UserProfile {
        let contextData = data["personalContext"] as? [String: Any] ?? [:]
        let context = PersonalContext(
            values: contextData["values"] as? [String] ?? [],
            goals: contextData["goals"] as? [String] ?? [],
            notes: contextData["notes"] as? String ?? ""
        )
        return UserProfile(
            id: id,
            displayName: data["displayName"] as? String ?? "",
            email: data["email"] as? String ?? "",
            photoURL: data["photoURL"] as? String,
            personalContext: context,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private func sessionFromData(_ data: [String: Any], id: String) throws -> CoachingSession {
        let transcriptData = data["transcript"] as? [[String: Any]] ?? []
        let transcript = transcriptData.map { msg in
            TranscriptMessage(
                id: msg["id"] as? String ?? UUID().uuidString,
                role: MessageRole(rawValue: msg["role"] as? String ?? "agent") ?? .agent,
                content: msg["content"] as? String ?? "",
                timestamp: (msg["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                coachId: msg["coachId"] as? String,
                coachName: msg["coachName"] as? String
            )
        }
        return CoachingSession(
            id: id,
            userId: data["userId"] as? String ?? "",
            coachId: data["coachId"] as? String ?? "",
            coachName: data["coachName"] as? String ?? "",
            additionalCoachIds: data["additionalCoachIds"] as? [String] ?? [],
            additionalCoachNames: data["additionalCoachNames"] as? [String] ?? [],
            startedAt: (data["startedAt"] as? Timestamp)?.dateValue() ?? Date(),
            endedAt: (data["endedAt"] as? Timestamp)?.dateValue(),
            durationSeconds: data["durationSeconds"] as? Int,
            elevenlabsConversationId: data["elevenlabsConversationId"] as? String,
            transcript: transcript
        )
    }

    private func coachConfigFromData(_ data: [String: Any], id: String) -> UserCoachConfig {
        UserCoachConfig(
            id: id,
            userId: data["userId"] as? String ?? "",
            sourceCoachId: data["sourceCoachId"] as? String ?? id,
            clonedAgentId: data["clonedAgentId"] as? String ?? "",
            enabledMCPServiceTypes: data["enabledMCPServiceTypes"] as? [String] ?? [],
            customName: data["customName"] as? String,
            customCategory: data["customCategory"] as? String,
            customOrbColors: data["customOrbColors"] as? [String],
            customVoiceId: data["customVoiceId"] as? String,
            customVoiceName: data["customVoiceName"] as? String,
            customSpeechSpeed: parsedOptionalDouble(data["customSpeechSpeed"]),
            customResponsePace: data["customResponsePace"] as? String,
            customQuickReplies: data["customQuickReplies"] as? Bool,
            customExpressiveStyle: data["customExpressiveStyle"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private func parsedDouble(_ value: Any?, fallback: Double) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String, let parsed = Double(value) { return parsed }
        return fallback
    }

    private func parsedOptionalDouble(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String, let parsed = Double(value) { return parsed }
        return nil
    }

    private func encodeToDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json
    }
}
