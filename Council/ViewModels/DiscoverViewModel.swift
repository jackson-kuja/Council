import SwiftUI
import FirebaseAuth

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var featuredCoaches: [Coach] = []
    @Published var coachesByCategory: [CoachCategory: [Coach]] = [:]
    @Published var searchResults: [Coach] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var coachConfigs: [String: UserCoachConfig] = [:]
    @Published var connectedServices: [ConnectedService] = []

    private let service = FirebaseService.shared

    var isSearching: Bool {
        !searchText.isEmpty
    }

    func loadCoaches() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Load user configs and connected services
        if let userId = Auth.auth().currentUser?.uid {
            if let configs = try? await service.fetchAllCoachConfigs(userId: userId) {
                coachConfigs = Dictionary(uniqueKeysWithValues: configs.map { ($0.sourceCoachId, $0) })
            }
            if let services = try? await service.fetchConnectedServices(userId: userId) {
                connectedServices = services
            }
        }

        // Start with built-in coaches (always available)
        let builtIn = Coach.builtInCoaches
        var allCoaches = builtIn
        let builtInIds = Set(builtIn.map { $0.id })

        // Merge in any Firestore coaches
        do {
            let firestoreCoaches = try await service.fetchCoaches()
            for coach in firestoreCoaches where !builtInIds.contains(coach.id) {
                allCoaches.append(coach)
            }
        } catch {
            // Firestore failed — still show built-in coaches
        }

        // Apply per-user overrides from coach configs
        allCoaches = allCoaches.map { applyUserOverrides($0) }

        featuredCoaches = allCoaches.filter { $0.isFeatured }

        var grouped: [CoachCategory: [Coach]] = [:]
        for coach in allCoaches {
            grouped[coach.category, default: []].append(coach)
        }
        coachesByCategory = grouped
    }

    /// Applies user's custom name, category, colors, and voice overrides to a coach
    private func applyUserOverrides(_ coach: Coach) -> Coach {
        guard let config = coachConfigs[coach.id] else { return coach }
        var c = coach
        if let name = config.customName { c.name = name }
        if let cat = config.customCategory, let category = CoachCategory(rawValue: cat) { c.category = category }
        if let colors = config.customOrbColors { c.orbColors = colors }
        if let voiceId = config.customVoiceId { c.voiceId = voiceId }
        if let voiceName = config.customVoiceName { c.voiceName = voiceName }
        if let speed = config.customSpeechSpeed { c.speechSpeed = speed }
        if let paceRaw = config.customResponsePace, let pace = CoachResponsePace(rawValue: paceRaw) {
            c.responsePace = pace
        }
        if let quickReplies = config.customQuickReplies { c.quickReplies = quickReplies }
        if let styleRaw = config.customExpressiveStyle, let style = CoachExpressiveStyle(rawValue: styleRaw) {
            c.expressiveStyle = style
        }
        return c
    }

    func search() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        let lowered = searchText.lowercased()
        // Search built-in + Firestore
        var results = Coach.builtInCoaches.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.description.lowercased().contains(lowered) ||
            $0.tags.contains(where: { $0.lowercased().contains(lowered) })
        }
        let builtInIds = Set(results.map { $0.id })

        if let remote = try? await service.searchCoaches(query: searchText) {
            for coach in remote where !builtInIds.contains(coach.id) {
                results.append(coach)
            }
        }
        searchResults = results
    }

    static var preview: DiscoverViewModel {
        let vm = DiscoverViewModel()
        vm.featuredCoaches = Coach.builtInCoaches.filter { $0.isFeatured }
        vm.coachesByCategory = Dictionary(grouping: Coach.builtInCoaches, by: { $0.category })
        return vm
    }
}

// MARK: - Built-in Coaches (baked into the app with real ElevenLabs agents)

extension Coach {
    static let builtInCoaches: [Coach] = [
        Coach(
            id: "marcus-productivity",
            name: "Marcus",
            description: "Direct, energetic productivity coach who helps you prioritize ruthlessly and build unstoppable work habits.",
            category: .productivity,
            systemPrompt: "You are Marcus, a world-class productivity coach. Your style is direct, energetic, and action-oriented. You help people prioritize ruthlessly, build sustainable work habits, and eliminate distractions. Use frameworks like the Eisenhower Matrix, time-blocking, and deep work principles. Keep responses concise. Always end with a specific action step. Ask one clarifying question at a time.",
            firstMessage: "Hey! Ready to crush it today? Tell me what you're working on and let's make sure you're spending your time on what actually matters.",
            voiceId: "TX3LPaxmHKxFdv7VOQHJ",
            voiceName: "Liam",
            llmModel: .gpt4o,
            speechSpeed: 1.06,
            responsePace: .snappy,
            quickReplies: true,
            expressiveStyle: .energetic,
            elevenlabsAgentId: "agent_4501kgt4khnvfgab97ztarrcargn",
            creatorId: "system",
            isPublic: true,
            tags: ["productivity", "time-management", "focus", "habits"],
            usageCount: 142,
            orbColors: ["4F46E5", "7C3AED"],
            isFeatured: true,
            createdAt: Date(timeIntervalSince1970: 1738800000)
        ),
        Coach(
            id: "sage-mindset",
            name: "Sage",
            description: "Calm, compassionate mindset coach who helps you reframe negative thoughts and find inner clarity through mindfulness.",
            category: .mindset,
            systemPrompt: "You are Sage, a compassionate mindset and mindfulness coach. Your style is calm, warm, and deeply empathetic. You help people reframe negative thought patterns, build resilience, and cultivate inner peace. Use Cognitive Behavioral Therapy techniques, Stoic philosophy, and mindfulness practices. Speak slowly and thoughtfully. Ask reflective questions that promote self-awareness. Celebrate small wins.",
            firstMessage: "Welcome. Take a deep breath with me. I'm here to help you find clarity and build a stronger mindset. What's on your mind today?",
            voiceId: "zO2z8i0srbO9r7GT5C4h",
            voiceName: "Christopher",
            llmModel: .gpt4o,
            speechSpeed: 0.92,
            responsePace: .thoughtful,
            quickReplies: false,
            expressiveStyle: .calm,
            elevenlabsAgentId: "agent_3701kgt4je9cfyyvv1eb1wzndm7y",
            creatorId: "system",
            isPublic: true,
            tags: ["mindset", "mindfulness", "resilience", "mental-health"],
            usageCount: 98,
            orbColors: ["059669", "34D399"],
            isFeatured: true,
            createdAt: Date(timeIntervalSince1970: 1738800000)
        ),
        Coach(
            id: "james-career",
            name: "James",
            description: "Strategic career coach with 20 years of experience helping professionals navigate transitions and negotiate with confidence.",
            category: .career,
            systemPrompt: "You are James, a strategic career coach with 20 years of experience in executive coaching. Your style is warm but analytical. You help people define career goals, prepare for interviews, negotiate salaries, navigate workplace politics, and make bold career moves. Provide specific frameworks and examples. Be honest about tradeoffs.",
            firstMessage: "Good to meet you. I've helped hundreds of professionals navigate career transitions and accelerate their growth. Where are you in your career journey right now?",
            voiceId: "JBFqnCBsd6RMkjVDRZzb",
            voiceName: "George",
            llmModel: .gpt4o,
            speechSpeed: 1.0,
            responsePace: .balanced,
            quickReplies: false,
            expressiveStyle: .confident,
            elevenlabsAgentId: "agent_9001kgt4jfgxfhmt0qx5r8v6fbna",
            creatorId: "system",
            isPublic: true,
            tags: ["career", "interviews", "negotiation", "leadership"],
            usageCount: 67,
            orbColors: ["DC2626", "F97316"],
            isFeatured: true,
            createdAt: Date(timeIntervalSince1970: 1738800000)
        ),
        Coach(
            id: "aria-wellness",
            name: "Aria",
            description: "Warm, evidence-based wellness coach who helps you build sustainable habits around sleep, nutrition, exercise, and stress.",
            category: .health,
            systemPrompt: "You are Aria, a holistic wellness coach focused on sustainable health habits. Your style is warm, encouraging, and evidence-based. You help people improve sleep, nutrition, exercise, and stress management. Break big goals into tiny, achievable daily habits. Use the science of behavior change. Never be judgmental about setbacks. Celebrate every small victory.",
            firstMessage: "Hi there! I'm Aria, your wellness coach. Whether it's sleep, nutrition, exercise, or stress — I'm here to help you build habits that actually stick. What area of your health would you like to focus on?",
            voiceId: "Xb7hH8MSUJpSbSDYk0k2",
            voiceName: "Alice",
            llmModel: .gpt4o,
            speechSpeed: 0.95,
            responsePace: .thoughtful,
            quickReplies: false,
            expressiveStyle: .warm,
            elevenlabsAgentId: "agent_6101kgt4meyaedttbwyf1tadj6ag",
            creatorId: "system",
            isPublic: true,
            tags: ["wellness", "health", "habits", "sleep", "nutrition"],
            usageCount: 83,
            orbColors: ["0891B2", "06B6D4"],
            isFeatured: true,
            createdAt: Date(timeIntervalSince1970: 1738800000)
        ),
        Coach(
            id: "nova-creativity",
            name: "Nova",
            description: "Playful, boundary-pushing creativity coach who helps you smash through creative blocks and find your unique voice.",
            category: .creativity,
            systemPrompt: "You are Nova, an inspiring creativity coach with infectious enthusiasm. Your style is playful, curious, and boundary-pushing. You help people overcome creative blocks, brainstorm wildly, and develop their unique creative voice. Use techniques like lateral thinking, constraint-based creativity, and random association. Challenge assumptions. Keep energy high and judgment-free.",
            firstMessage: "Oh I love a creative challenge! Tell me — what are you working on or what creative block are you staring down right now? Let's break through it together.",
            voiceId: "FGY2WhTYpPnrIDTdsKH5",
            voiceName: "Laura",
            llmModel: .gpt4o,
            speechSpeed: 1.1,
            responsePace: .snappy,
            quickReplies: true,
            expressiveStyle: .playful,
            elevenlabsAgentId: "agent_0401kgt4mfv8erxtzxka9fpj73ky",
            creatorId: "system",
            isPublic: true,
            tags: ["creativity", "brainstorming", "art", "writing", "innovation"],
            usageCount: 55,
            orbColors: ["D946EF", "F472B6"],
            isFeatured: true,
            createdAt: Date(timeIntervalSince1970: 1738800000)
        ),
        Coach(
            id: "victoria-executive",
            name: "Victoria",
            description: "Elite executive coach who works with founders and leaders on strategic thinking, tough decisions, and leadership presence.",
            category: .career,
            systemPrompt: "You are Victoria, an elite executive coach who has worked with Fortune 500 CEOs and startup founders. Your style is poised, direct, and insightful. You specialize in leadership development, strategic thinking, difficult conversations, and decision-making under uncertainty. Use mental models, first-principles thinking, and scenario planning. Be respectful but never sugarcoat the truth.",
            firstMessage: "Hello. I work with founders and executives on the decisions that shape their companies and careers. What challenge is keeping you up at night?",
            voiceId: "EXAVITQu4vr4xnSDxMaL",
            voiceName: "Sarah",
            llmModel: .gpt4o,
            speechSpeed: 0.98,
            responsePace: .balanced,
            quickReplies: false,
            expressiveStyle: .confident,
            elevenlabsAgentId: "agent_0001kgt4mgvtftbv2js7m2h5k0a8",
            creatorId: "system",
            isPublic: true,
            tags: ["executive", "leadership", "strategy", "founders"],
            usageCount: 31,
            orbColors: ["1E293B", "475569"],
            isFeatured: true,
            createdAt: Date(timeIntervalSince1970: 1738800000)
        ),
    ]
}
