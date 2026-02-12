import SwiftUI
import UIKit
import AVFoundation
import CoreHaptics
import ElevenLabs
import ElevenLabsComponents
import FirebaseAuth

private struct VoiceSegment {
    let coachId: String
    let coachName: String
    let text: String
}

@MainActor
class SessionViewModel: ObservableObject {
    @Published var conversation: Conversation?
    @Published var messages: [TranscriptMessage] = []
    @Published var agentState: String = "Idle"
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var isMuted = false
    @Published var error: String?
    @Published var sessionDuration: Int = 0
    @Published var activeCoaches: [Coach] = []
    @Published var speakingCoachId: String?
    @Published var isAddingCoach = false

    var canAddCoach: Bool { activeCoaches.count < 3 && isConnected }

    private(set) var coach: Coach
    private var userProfile: UserProfile = .empty

    private var sessionStartTime: Date?
    private var durationTimer: Timer?
    private var currentSessionId: String?
    private var previousAgentState: String = "Idle"
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?
    private var audioProcessor: AudioProcessor?
    private var hapticTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var conversationStateTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var cachedFullPrompt: String?
    private var priorSessions: [CoachingSession] = []
    private var resolvedAgentId: String?
    private var shouldReconnectOnForeground = false
    private var isEndingSession = false
    private var ignoreNextDisconnect = false
    private var reconnectAttempts = 0

    private let maxStartupAttempts = 2
    private let startupRetryDelayNanoseconds: UInt64 = 800_000_000
    private let maxReconnectAttempts = 3

    private static let warmUpPhrases = [
        "Setting the stage",
        "Getting ready",
        "One moment",
        "Warming up",
        "Almost there",
        "Tuning in",
    ]

    private lazy var sessionWarmUpPhrase: String = {
        Self.warmUpPhrases.randomElement() ?? "Getting ready"
    }()

    /// The agent ID to use for ElevenLabs API calls (always user's v3-configured clone)
    private var effectiveAgentId: String {
        resolvedAgentId ?? ""
    }

    init(coach: Coach) {
        self.coach = coach
        self.activeCoaches = [coach]
        registerAudioSessionObservers()
        registerSessionActionObserver()
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        startupTask?.cancel()
        conversationStateTask?.cancel()
        reconnectTask?.cancel()
        hapticTask?.cancel()
    }

    func loadProfileAndStart() async {
        guard startupTask == nil, !isConnected, !isConnecting else { return }

        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }

            if let userId = Auth.auth().currentUser?.uid {
                if let profile = try? await FirebaseService.shared.fetchUserProfile(userId: userId) {
                    userProfile = profile
                    cachedFullPrompt = nil
                }

                // Fetch all prior sessions with this coach for conversation history
                self.priorSessions = (try? await FirebaseService.shared.fetchSessionsForCoach(
                    userId: userId, coachId: self.coach.id
                )) ?? []

                // Resolve per-user cloned agent ID (lazy clone on first session)
                await resolveAgentId(userId: userId)
            }

            guard !Task.isCancelled else { return }
            guard !self.effectiveAgentId.isEmpty else {
                self.error = "Unable to prepare your coach. Please try again."
                self.isConnecting = false
                self.agentState = "Idle"
                return
            }
            await startSession(isRecovery: false)
        }

        await startupTask?.value
        startupTask = nil
    }

    func cancelPendingStartup() {
        startupTask?.cancel()
        startupTask = nil

        if isConnecting, !isConnected {
            isConnecting = false
            agentState = "Idle"
        }
    }

    /// Resolves the per-user ElevenLabs agent ID, cloning the template agent on first use
    private func resolveAgentId(userId: String) async {
        // Check for existing config
        if let config = try? await FirebaseService.shared.fetchCoachConfig(
            userId: userId, sourceCoachId: coach.id
        ) {
            resolvedAgentId = config.clonedAgentId

            // Ensure MCP servers are applied if the user has enabled any
            if !config.enabledMCPServiceTypes.isEmpty {
                await applyMCPServers(
                    agentId: config.clonedAgentId,
                    enabledTypes: config.enabledMCPServiceTypes,
                    userId: userId
                )
            }
            return
        }

        // Clone the agent for this user
        do {
            let clonedId = try await ElevenLabsAPIService.shared.cloneAgent(
                name: "\(userProfile.displayName)'s \(coach.name)",
                systemPrompt: coach.systemPrompt,
                firstMessage: coach.firstMessage,
                voiceId: coach.voiceId,
                llmModel: coach.llmModel.rawValue,
                speechSpeed: coach.speechSpeed,
                responsePace: coach.responsePace,
                quickReplies: coach.quickReplies,
                expressiveStyle: coach.expressiveStyle
            )
            let config = UserCoachConfig(
                id: coach.id,
                userId: userId,
                sourceCoachId: coach.id,
                clonedAgentId: clonedId,
                enabledMCPServiceTypes: [],
                customName: nil,
                customCategory: nil,
                customOrbColors: nil,
                customVoiceId: nil,
                customVoiceName: nil,
                customSpeechSpeed: nil,
                customResponsePace: nil,
                customQuickReplies: nil,
                customExpressiveStyle: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await FirebaseService.shared.saveCoachConfig(userId: userId, config: config)
            resolvedAgentId = clonedId
        } catch {
            resolvedAgentId = nil
        }
    }

    /// Applies MCP server attachments to a cloned agent based on enabled service types
    private func applyMCPServers(agentId: String, enabledTypes: [String], userId: String) async {
        do {
            let connectedServices = try await FirebaseService.shared.fetchConnectedServices(userId: userId)
            let mcpServerIds = enabledTypes.compactMap { typeRaw -> String? in
                guard let type = ServiceType(rawValue: typeRaw) else { return nil }
                return connectedServices.first { $0.serviceType == type && $0.isConnected }?.mcpServerId
            }
            if !mcpServerIds.isEmpty {
                try await ElevenLabsAPIService.shared.updateAgentMCP(
                    agentId: agentId,
                    mcpServerIds: mcpServerIds
                )
            }
        } catch {
            // Non-fatal: session can proceed without MCP
        }
    }

    func startSession(isRecovery: Bool = false) async {
        guard !isConnecting, !isConnected else { return }

        isConnecting = true
        agentState = isRecovery ? "Reconnecting" : sessionWarmUpPhrase
        if !isRecovery {
            error = nil
        }
        previousAgentState = "Idle"
        ignoreNextDisconnect = false

        do {
            try configureAudioSessionForConversation()

            let fullPrompt = resolvedFullPrompt()
            let conv = try await startConversationWithRetry(fullPrompt: fullPrompt)
            try Task.checkCancellation()

            conversation = conv
            isConnected = true
            isConnecting = false
            shouldReconnectOnForeground = false
            reconnectAttempts = 0
            agentState = "Listening"

            if !isRecovery {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

            if sessionStartTime == nil {
                sessionStartTime = Date()
            }
            if currentSessionId == nil {
                currentSessionId = UUID().uuidString
            }
            if let start = sessionStartTime {
                sessionDuration = max(sessionDuration, Int(Date().timeIntervalSince(start)))
            }

            startDurationTimer()

            setupHapticEngine()
            audioProcessor = AudioProcessor(track: conv.agentAudioTrack, bandCount: 7)

            try? await FirebaseService.shared.incrementUsageCount(coachId: coach.id)
            observeConversation(conv)
            await syncLiveActivity()

        } catch is CancellationError {
            isConnecting = false
            if !isConnected {
                agentState = "Idle"
            }
        } catch {
            isConnecting = false
            agentState = isRecovery ? "Reconnecting" : "Idle"
            self.error = error.localizedDescription
            if isRecovery {
                shouldReconnectOnForeground = true
            }
            await syncLiveActivity(statusOverride: "Connection lost", connectedOverride: false)
        }
    }

    func endSession() async {
        isEndingSession = true
        shouldReconnectOnForeground = false
        reconnectTask?.cancel()
        reconnectTask = nil

        startupTask?.cancel()
        startupTask = nil
        endBackgroundTransitionTask()

        let startedAt = sessionStartTime ?? Date()
        let elapsed = max(sessionDuration, Int(Date().timeIntervalSince(startedAt)))
        let sessionId = currentSessionId

        ignoreNextDisconnect = true
        await conversation?.endConversation()

        if let sessionId = currentSessionId {
            let additionalCoaches = Array(activeCoaches.dropFirst())
            let session = CoachingSession(
                id: sessionId,
                userId: userProfile.id,
                coachId: coach.id,
                coachName: coach.name,
                additionalCoachIds: additionalCoaches.map(\.id),
                additionalCoachNames: additionalCoaches.map(\.name),
                startedAt: sessionStartTime ?? Date(),
                endedAt: Date(),
                durationSeconds: elapsed,
                elevenlabsConversationId: nil,
                transcript: messages
            )
            try? await FirebaseService.shared.saveSession(session)
        }

        if activeCoaches.count > 1 {
            try? await ElevenLabsAPIService.shared.updateAgentMultiVoice(
                agentId: effectiveAgentId,
                supportedVoices: []
            )
        }

        if let sessionId {
            await LiveActivityManager.shared.end(
                sessionId: sessionId,
                statusLabel: "Ended",
                isMuted: isMuted,
                isConnected: false,
                startedAt: startedAt,
                elapsedSeconds: elapsed
            )
        }

        resetConnectionState()
        resetSessionContext()
        deactivateAudioSession()
        activeCoaches = [coach]
        speakingCoachId = nil
        agentState = "Idle"
        isEndingSession = false
    }

    func toggleMute() async {
        guard let conv = conversation else { return }
        do {
            try await conv.toggleMute()
            isMuted = conv.isMuted
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            await syncLiveActivity()
        } catch {
            self.error = "Failed to toggle mute"
        }
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            endBackgroundTransitionTask()
            attemptForegroundRecoveryIfNeeded()
        case .background:
            guard currentSessionId != nil, !isEndingSession else { return }
            shouldReconnectOnForeground = true
            beginBackgroundTransitionTask()
            Task {
                await syncLiveActivity(
                    statusOverride: isConnected ? "Background" : "Paused",
                    connectedOverride: isConnected
                )
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Multi-Coach

    func addCoach(_ newCoach: Coach) async {
        guard activeCoaches.count < 3 else { return }
        guard !activeCoaches.contains(where: { $0.id == newCoach.id }) else { return }

        isAddingCoach = true
        agentState = "Adding coach"

        let transcriptSnapshot = messages

        await prepareForConversationTransition(statusLabel: "Adding coach")

        activeCoaches.append(newCoach)

        do {
            let secondaryCoaches = Array(activeCoaches.dropFirst())
            try await ElevenLabsAPIService.shared.updateAgentMultiVoice(
                agentId: effectiveAgentId,
                supportedVoices: secondaryCoaches.map { c in
                    SupportedVoice(
                        voiceId: c.voiceId,
                        label: c.voiceLabel,
                        description: "Use this voice when speaking as \(c.name)"
                    )
                }
            )
        } catch {
            activeCoaches.removeLast()
            self.error = "Failed to add coach: \(error.localizedDescription)"
            isAddingCoach = false
            await startSession(isRecovery: true)
            return
        }

        let mergedPrompt = buildMultiCoachPrompt(
            coaches: activeCoaches,
            transcript: transcriptSnapshot
        )

        agentState = "Reconnecting"
        do {
            try await restartConversation(with: mergedPrompt)
            isAddingCoach = false
        } catch {
            activeCoaches.removeLast()
            isAddingCoach = false
            self.error = "Failed to restart session: \(error.localizedDescription)"
            await startSession(isRecovery: true)
        }
    }

    func removeCoach(_ coachToRemove: Coach) async {
        guard coachToRemove.id != coach.id else { return }
        guard activeCoaches.contains(where: { $0.id == coachToRemove.id }) else { return }

        isAddingCoach = true
        agentState = "Removing coach"

        let transcriptSnapshot = messages

        await prepareForConversationTransition(statusLabel: "Removing coach")

        activeCoaches.removeAll { $0.id == coachToRemove.id }

        do {
            if activeCoaches.count == 1 {
                try await ElevenLabsAPIService.shared.updateAgentMultiVoice(
                    agentId: effectiveAgentId,
                    supportedVoices: []
                )
            } else {
                let secondaryCoaches = Array(activeCoaches.dropFirst())
                try await ElevenLabsAPIService.shared.updateAgentMultiVoice(
                    agentId: effectiveAgentId,
                    supportedVoices: secondaryCoaches.map { c in
                        SupportedVoice(
                            voiceId: c.voiceId,
                            label: c.voiceLabel,
                            description: "Use this voice when speaking as \(c.name)"
                        )
                    }
                )
            }
        } catch {
            self.error = "Failed to update voice config: \(error.localizedDescription)"
        }

        let prompt: String
        if activeCoaches.count == 1 {
            prompt = buildSingleCoachPromptWithTranscript(transcript: transcriptSnapshot)
        } else {
            prompt = buildMultiCoachPrompt(coaches: activeCoaches, transcript: transcriptSnapshot)
        }

        agentState = "Reconnecting"
        do {
            try await restartConversation(with: prompt)
            isAddingCoach = false
        } catch {
            isAddingCoach = false
            self.error = "Failed to restart: \(error.localizedDescription)"
            await startSession(isRecovery: true)
        }
    }

    // MARK: - Private

    private func restartConversation(with prompt: String) async throws {
        try configureAudioSessionForConversation()
        let conv = try await startConversationWithRetry(fullPrompt: prompt)
        conversation = conv
        isConnected = true
        isConnecting = false
        shouldReconnectOnForeground = false
        reconnectAttempts = 0
        agentState = "Listening"
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
        if currentSessionId == nil {
            currentSessionId = UUID().uuidString
        }
        if let start = sessionStartTime {
            sessionDuration = max(sessionDuration, Int(Date().timeIntervalSince(start)))
        }

        startDurationTimer()
        setupHapticEngine()
        audioProcessor = AudioProcessor(track: conv.agentAudioTrack, bandCount: 7)
        observeConversation(conv)
        await syncLiveActivity()
    }

    private func buildMultiCoachPrompt(coaches: [Coach], transcript: [TranscriptMessage]) -> String {
        var sections: [String] = []

        let coachNames = coaches.map(\.name).joined(separator: ", ")
        var preamble = """
        You are a multi-coach AI system with \(coaches.count) coaches in this session: \(coachNames).
        Each coach has a distinct personality, expertise, and voice. You MUST stay in character for each coach.

        CRITICAL VOICE RULES:
        - The primary coach (\(coaches.first?.name ?? "Coach")) speaks with UNTAGGED text (no XML tags needed).
        """
        for c in coaches.dropFirst() {
            preamble += "\n- When speaking as \(c.name), wrap text in <\(c.voiceLabel)>...</\(c.voiceLabel)> tags."
        }
        preamble += """

        INTERACTION RULES:
        - Let the most relevant coach respond. Do NOT have all coaches speak on every turn.
        - When multiple coaches speak in one turn, keep each contribution concise (1-3 sentences each).
        - Coaches should address the user directly, not talk to each other at length.
        """
        sections.append(preamble)

        for (index, c) in coaches.enumerated() {
            let role = index == 0 ? "(PRIMARY - default voice, no XML tags)" : "(voice label: \(c.voiceLabel))"
            sections.append("--- COACH: \(c.name) \(role) ---\n\(c.systemPrompt)")
        }

        if !userProfile.personalContext.isEmpty {
            sections.append(userProfile.personalContext.formattedForPrompt(userName: userProfile.displayName))
        }

        sections.append("{{coaching_history}}")

        if !transcript.isEmpty {
            sections.append(transcriptSection(transcript: transcript, coaches: coaches,
                                              suffix: "Continue the conversation naturally. A new coach (\(coaches.last?.name ?? "Coach")) has just joined — they may briefly acknowledge joining, then continue coaching."))
        }

        return sections.joined(separator: "\n\n")
    }

    private func buildSingleCoachPromptWithTranscript(transcript: [TranscriptMessage]) -> String {
        var fullPrompt = coach.systemPrompt

        if !userProfile.personalContext.isEmpty {
            fullPrompt += "\n\n" + userProfile.personalContext.formattedForPrompt(
                userName: userProfile.displayName
            )
        }

        fullPrompt += "\n\n{{coaching_history}}"

        if !transcript.isEmpty {
            fullPrompt += "\n\n" + transcriptSection(transcript: transcript, coaches: activeCoaches,
                                                      suffix: "Continue the conversation naturally. Do NOT greet the user again.")
        }

        return fullPrompt
    }

    private func formattedCoachingHistory() -> String {
        guard !priorSessions.isEmpty else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var lines: [String] = ["--- PRIOR COACHING SESSIONS ---"]

        for session in priorSessions {
            lines.append("\n[Session: \(dateFormatter.string(from: session.startedAt))]")
            for msg in session.transcript {
                let speaker = msg.role == .user ? "User" : (msg.coachName ?? coach.name)
                lines.append("\(speaker): \(msg.content)")
            }
        }

        lines.append("\n--- END PRIOR SESSIONS ---")
        lines.append("Use the above conversation history to maintain continuity. Reference past discussions, follow up on commitments, and build on previous insights. Do NOT repeat or summarize the history to the user unless asked.")

        return lines.joined(separator: "\n")
    }

    private func transcriptSection(transcript: [TranscriptMessage], coaches: [Coach], suffix: String) -> String {
        let recentTranscript: [TranscriptMessage]
        var lines: [String] = ["--- CONVERSATION SO FAR (continue from here, do NOT repeat) ---"]

        if transcript.count > 50 {
            recentTranscript = Array(transcript.suffix(50))
            lines.append("[Earlier conversation messages omitted]")
        } else {
            recentTranscript = transcript
        }

        for msg in recentTranscript {
            let speaker = msg.role == .user ? "User" : (msg.coachName ?? coaches.first?.name ?? "Coach")
            lines.append("\(speaker): \(msg.content)")
        }

        lines.append("--- END OF PREVIOUS CONVERSATION ---")
        lines.append(suffix)

        return lines.joined(separator: "\n")
    }

    private func processAgentResponse(_ rawText: String) {
        guard activeCoaches.count > 1 else {
            addMessage(role: .agent, content: rawText, coachId: coach.id, coachName: coach.name)
            speakingCoachId = coach.id
            return
        }

        let segments = parseMultiVoiceResponse(rawText)
        for segment in segments {
            addMessage(role: .agent, content: segment.text, coachId: segment.coachId, coachName: segment.coachName)
            speakingCoachId = segment.coachId
        }
    }

    private func parseMultiVoiceResponse(_ rawText: String) -> [VoiceSegment] {
        guard let primaryCoach = activeCoaches.first else {
            return [VoiceSegment(coachId: "", coachName: "Coach", text: rawText)]
        }

        var labelToCoach: [String: Coach] = [:]
        for c in activeCoaches.dropFirst() {
            labelToCoach[c.voiceLabel] = c
        }

        guard !labelToCoach.isEmpty else {
            return [VoiceSegment(coachId: primaryCoach.id, coachName: primaryCoach.name, text: rawText)]
        }

        let labels = labelToCoach.keys.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let pattern = "<(\(labels))>(.*?)</\\1>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return [VoiceSegment(coachId: primaryCoach.id, coachName: primaryCoach.name, text: rawText)]
        }

        var segments: [VoiceSegment] = []
        let nsText = rawText as NSString
        var lastEnd = 0
        let matches = regex.matches(in: rawText, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let beforeText = nsText.substring(with: beforeRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !beforeText.isEmpty {
                segments.append(VoiceSegment(coachId: primaryCoach.id, coachName: primaryCoach.name, text: beforeText))
            }

            let label = nsText.substring(with: match.range(at: 1))
            let content = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty, let taggedCoach = labelToCoach[label] {
                segments.append(VoiceSegment(coachId: taggedCoach.id, coachName: taggedCoach.name, text: content))
            }

            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                segments.append(VoiceSegment(coachId: primaryCoach.id, coachName: primaryCoach.name, text: remaining))
            }
        }

        if segments.isEmpty {
            segments.append(VoiceSegment(coachId: primaryCoach.id, coachName: primaryCoach.name, text: rawText))
        }

        return segments
    }

    private func addMessage(role: MessageRole, content: String, coachId: String? = nil, coachName: String? = nil) {
        let msg = TranscriptMessage(role: role, content: content, coachId: coachId, coachName: coachName)
        messages.append(msg)
    }

    private func resetConnectionState() {
        conversation = nil
        isConnected = false
        isConnecting = false
        previousAgentState = "Idle"
        speakingCoachId = nil
        conversationStateTask?.cancel()
        conversationStateTask = nil
        durationTimer?.invalidate()
        durationTimer = nil
        stopAudioHaptics()
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        audioProcessor = nil
    }

    private func resetSessionContext() {
        currentSessionId = nil
        sessionStartTime = nil
        sessionDuration = 0
        shouldReconnectOnForeground = false
        reconnectAttempts = 0
        cachedFullPrompt = nil
    }

    private func resolvedFullPrompt() -> String {
        if activeCoaches.count > 1 {
            return buildMultiCoachPrompt(coaches: activeCoaches, transcript: messages)
        }

        if let cachedFullPrompt {
            return cachedFullPrompt
        }

        var fullPrompt = coach.systemPrompt
        if !userProfile.personalContext.isEmpty {
            fullPrompt += "\n\n" + userProfile.personalContext.formattedForPrompt(
                userName: userProfile.displayName
            )
        }

        fullPrompt += "\n\n{{coaching_history}}"

        cachedFullPrompt = fullPrompt
        return fullPrompt
    }

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let start = self.sessionStartTime {
                    self.sessionDuration = max(self.sessionDuration, Int(Date().timeIntervalSince(start)))
                } else {
                    self.sessionDuration += 1
                }
            }
        }
    }

    private func prepareForConversationTransition(statusLabel: String) async {
        ignoreNextDisconnect = true
        await conversation?.endConversation()
        resetConnectionState()
        deactivateAudioSession()
        agentState = statusLabel
        await syncLiveActivity(statusOverride: statusLabel, connectedOverride: false)
    }

    private func handleUnexpectedDisconnect() {
        guard !isEndingSession else { return }

        resetConnectionState()
        deactivateAudioSession()

        guard currentSessionId != nil else {
            agentState = "Idle"
            return
        }

        shouldReconnectOnForeground = true
        reconnectAttempts = 0
        agentState = "Reconnecting"
        scheduleReconnect()

        Task {
            await syncLiveActivity(statusOverride: agentState, connectedOverride: false)
        }
    }

    private func attemptForegroundRecoveryIfNeeded() {
        guard shouldReconnectOnForeground, !isConnected, !isConnecting, !isEndingSession else { return }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard reconnectTask == nil else { return }

        reconnectTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var backoff: UInt64 = 700_000_000

            while self.shouldReconnectOnForeground,
                  !self.isConnected,
                  !self.isConnecting,
                  !self.isEndingSession,
                  self.reconnectAttempts < self.maxReconnectAttempts {
                self.reconnectAttempts += 1
                await self.startSession(isRecovery: true)

                if self.isConnected {
                    self.reconnectTask = nil
                    return
                }

                try? await Task.sleep(nanoseconds: backoff)
                backoff = min(backoff * 2, 4_000_000_000)
            }

            self.reconnectTask = nil
            if !self.isConnected {
                self.agentState = "Connection lost"
                await self.syncLiveActivity(statusOverride: self.agentState, connectedOverride: false)
            }
        }
    }

    private func syncLiveActivity(
        statusOverride: String? = nil,
        connectedOverride: Bool? = nil
    ) async {
        guard let sessionId = currentSessionId, let startedAt = sessionStartTime else { return }

        let primaryColor = coach.orbColors.first ?? "6366F1"
        let secondaryColor = coach.orbColors.dropFirst().first ?? primaryColor
        let statusLabel = statusOverride ?? agentState
        let connected = connectedOverride ?? isConnected

        await LiveActivityManager.shared.start(
            sessionId: sessionId,
            coachName: activeCoaches.map(\.name).joined(separator: " + "),
            primaryColorHex: primaryColor,
            secondaryColorHex: secondaryColor,
            statusLabel: statusLabel,
            isMuted: isMuted,
            isConnected: connected,
            startedAt: startedAt,
            elapsedSeconds: sessionDuration
        )
    }

    private func registerAudioSessionObservers() {
        let observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAudioSessionInterruption(notification)
            }
        }
        notificationObservers.append(observer)
    }

    private func registerSessionActionObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: .sessionDeepLinkActionRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                guard self.currentSessionId != nil, !self.isEndingSession else { return }
                guard let rawAction = notification.userInfo?["action"] as? String,
                      let action = SessionDeepLinkAction(rawValue: rawAction) else {
                    return
                }

                switch action {
                case .open:
                    break
                case .mute:
                    await self.toggleMute()
                case .end:
                    await self.endSession()
                }
            }
        }
        notificationObservers.append(observer)
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            guard currentSessionId != nil, !isEndingSession else { return }
            shouldReconnectOnForeground = true
            agentState = "Interrupted"
            Task {
                await syncLiveActivity(statusOverride: "Interrupted", connectedOverride: isConnected)
            }
        case .ended:
            try? configureAudioSessionForConversation()
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if options.contains(.shouldResume), !isConnected, !isConnecting, !isEndingSession {
                scheduleReconnect()
            }
        @unknown default:
            break
        }
    }

    private func configureAudioSessionForConversation() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        try audioSession.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginBackgroundTransitionTask() {
        guard backgroundTaskId == .invalid else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "CouncilSession") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTransitionTask()
            }
        }
    }

    private func endBackgroundTransitionTask() {
        guard backgroundTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }

    private func startConversationWithRetry(fullPrompt: String) async throws -> Conversation {
        var lastError: Error?

        for attempt in 1...maxStartupAttempts {
            do {
                return try await ElevenLabs.startConversation(
                    agentId: effectiveAgentId,
                    config: ConversationConfig(
                        agentOverrides: AgentOverrides(prompt: fullPrompt),
                        dynamicVariables: ["coaching_history": formattedCoachingHistory()],
                        onDisconnect: { [weak self] _ in
                            Task { @MainActor in
                                guard let self else { return }
                                if self.ignoreNextDisconnect {
                                    self.ignoreNextDisconnect = false
                                    return
                                }
                                self.handleUnexpectedDisconnect()
                            }
                        },
                        onStartupStateChange: { [weak self] state in
                            Task { @MainActor in
                                self?.agentState = self?.labelForStartupState(state) ?? "Connecting"
                            }
                        },
                        startupConfiguration: ConversationStartupConfiguration(
                            agentReadyTimeout: 8.0,
                            initRetryDelays: [0, 0.4, 1.0],
                            failIfAgentNotReady: false
                        ),
                        onAgentResponse: { [weak self] text, _ in
                            Task { @MainActor in
                                self?.processAgentResponse(text)
                            }
                        },
                        onUserTranscript: { [weak self] text, _ in
                            Task { @MainActor in
                                self?.addMessage(role: .user, content: text)
                            }
                        }
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error

                guard attempt < maxStartupAttempts,
                      shouldRetryAfterStartupFailure(error) else {
                    throw error
                }

                agentState = "Retrying connection"
                try? await Task.sleep(nanoseconds: startupRetryDelayNanoseconds)
            }
        }

        throw lastError ?? ConversationError.connectionFailed("Unknown startup failure")
    }

    private func shouldRetryAfterStartupFailure(_ error: Error) -> Bool {
        if let conversationError = error as? ConversationError {
            switch conversationError {
            case let .connectionFailed(description):
                let description = description.lowercased()
                return description.contains("timed out") || description.contains("network")
            default:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == "io.livekit.swift-sdk", nsError.code == 101 {
            return true
        }

        return error.localizedDescription.lowercased().contains("timed out")
    }

    private func labelForStartupState(_ state: ConversationStartupState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .resolvingToken, .connectingRoom, .waitingForAgent, .sendingConversationInit, .agentReady:
            return sessionWarmUpPhrase
        case .active:
            return "Listening"
        case .failed:
            return "Connection failed"
        }
    }

    private func observeConversation(_ conv: Conversation) {
        conversationStateTask?.cancel()
        conversationStateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.isConnected, !Task.isCancelled {
                let newState: String
                switch conv.agentState {
                case .listening:
                    newState = "Listening"
                case .speaking:
                    newState = "Speaking"
                case .thinking:
                    newState = "Thinking"
                @unknown default:
                    newState = "Active"
                }

                var shouldSyncActivity = false

                if newState != self.previousAgentState {
                    self.hapticForStateChange(newState)
                    if newState == "Speaking" {
                        self.startAudioHaptics()
                    } else if self.previousAgentState == "Speaking" {
                        self.stopAudioHaptics()
                    }
                    self.previousAgentState = newState
                    shouldSyncActivity = true
                }
                self.agentState = newState

                let muted = conv.isMuted
                if muted != self.isMuted {
                    self.isMuted = muted
                    shouldSyncActivity = true
                }

                if shouldSyncActivity {
                    await self.syncLiveActivity()
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func hapticForStateChange(_ newState: String) {
        switch newState {
        case "Speaking":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "Listening":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "Thinking":
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        default:
            break
        }
    }

    // MARK: - Audio-Synced Haptics

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
            try hapticEngine?.start()
        } catch {}
    }

    private func startAudioHaptics() {
        guard let engine = hapticEngine else { return }

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0,
            duration: 300
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            hapticPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try hapticPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {}

        // Poll at 30ms (~33fps) to stay tight with the orb's visual pulse
        hapticTask = Task { @MainActor [weak self] in
            while self?.agentState == "Speaking", let self = self {
                if let bands = self.audioProcessor?.bands {
                    let volume = self.hapticVolume(from: bands)
                    let intensity = CHHapticDynamicParameter(
                        parameterID: .hapticIntensityControl,
                        value: volume,
                        relativeTime: 0
                    )
                    try? self.hapticPlayer?.sendParameters([intensity], atTime: CHHapticTimeImmediate)
                }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    private func stopAudioHaptics() {
        hapticTask?.cancel()
        hapticTask = nil
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        hapticPlayer = nil
    }

    private func hapticVolume(from bands: [Float]) -> Float {
        guard !bands.isEmpty else { return 0.0 }
        let average = bands.reduce(0, +) / Float(bands.count)
        // No baseline, no compression — raw dynamics so pauses = silence, loud = strong
        return min(average * 3.0, 1.0)
    }

    var visualizerState: VisualizerAgentState {
        guard let conversation = conversation else { return .unknown }
        switch conversation.agentState {
        case .listening: return .listening
        case .speaking: return .speaking
        case .thinking: return .thinking
        @unknown default: return .unknown
        }
    }

    var formattedDuration: String {
        let minutes = sessionDuration / 60
        let seconds = sessionDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
