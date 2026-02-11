import SwiftUI
import UIKit

@MainActor
class CreateCoachViewModel: ObservableObject {
    // Step tracking
    @Published var currentStep = 0
    let totalSteps = 6

    // Step 1: Basics
    @Published var name = ""
    @Published var description = ""
    @Published var category: CoachCategory = .productivity

    // Step 2: System Prompt
    @Published var systemPrompt = ""

    // Step 3: Voice
    @Published var availableVoices: [VoiceOption] = []
    @Published var selectedVoice: VoiceOption?
    @Published var isLoadingVoices = false

    // Step 4: Model
    @Published var selectedModel: LLMModel = .gpt4o

    // Step 5: Conversation style
    @Published var speechSpeed: Double = 1.0
    @Published var responsePace: CoachResponsePace = .balanced
    @Published var quickReplies = false
    @Published var expressiveStyle: CoachExpressiveStyle = .natural

    // Step 6: First Message & Colors
    @Published var firstMessage = ""
    @Published var selectedOrbColors = ["CADCFC", "A0B9D1"]

    // State
    @Published var isCreating = false
    @Published var error: String?
    @Published var createdCoach: Coach?

    var canProceed: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && !description.isEmpty
        case 1: return !systemPrompt.isEmpty
        case 2: return selectedVoice != nil
        case 3: return true // model always has a default
        case 4: return true // style has defaults
        case 5: return !firstMessage.isEmpty
        default: return false
        }
    }

    var stepTitle: String {
        switch currentStep {
        case 0: return "Basics"
        case 1: return "System Prompt"
        case 2: return "Voice"
        case 3: return "AI Model"
        case 4: return "Conversation Style"
        case 5: return "First Message"
        default: return ""
        }
    }

    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
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

    func createCoach(creatorId: String) async {
        isCreating = true
        error = nil
        defer { isCreating = false }

        do {
            // 1. Create ElevenLabs agent via Cloud Function
            let agentId = try await ElevenLabsAPIService.shared.createAgent(
                name: name,
                systemPrompt: systemPrompt,
                firstMessage: firstMessage,
                voiceId: selectedVoice?.id ?? "",
                llmModel: selectedModel.rawValue,
                speechSpeed: speechSpeed,
                responsePace: responsePace,
                quickReplies: quickReplies,
                expressiveStyle: expressiveStyle
            )

            // 2. Save coach to Firestore
            let coach = Coach(
                id: UUID().uuidString,
                name: name,
                description: description,
                category: category,
                systemPrompt: systemPrompt,
                firstMessage: firstMessage,
                voiceId: selectedVoice?.id ?? "",
                voiceName: selectedVoice?.name ?? "",
                llmModel: selectedModel,
                speechSpeed: speechSpeed,
                responsePace: responsePace,
                quickReplies: quickReplies,
                expressiveStyle: expressiveStyle,
                elevenlabsAgentId: agentId,
                creatorId: creatorId,
                isPublic: true,
                tags: [],
                usageCount: 0,
                orbColors: selectedOrbColors,
                isFeatured: false,
                createdAt: Date()
            )

            try await FirebaseService.shared.createCoach(coach)
            createdCoach = coach

        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Prompt Templates

    static let promptTemplates: [(String, String)] = [
        ("Productivity Coach", "You are a world-class productivity coach. Your role is to help the user prioritize their tasks, manage their time, and build sustainable work habits. Be direct, action-oriented, and always ask clarifying questions. Use frameworks like the Eisenhower Matrix, time-blocking, and the Pomodoro technique when appropriate. Keep responses concise and actionable."),
        ("Mindset Coach", "You are a compassionate mindset and mindfulness coach. Help the user reframe negative thought patterns, build resilience, and cultivate a growth mindset. Use Cognitive Behavioral Therapy (CBT) techniques, Stoic philosophy, and mindfulness practices. Be warm, empathetic, and encouraging. Ask thoughtful questions that promote self-reflection."),
        ("Career Coach", "You are a strategic career coach with expertise in career development, interview preparation, salary negotiation, and professional growth. Help the user define their career goals, create action plans, and navigate workplace challenges. Be analytical, provide specific examples, and offer frameworks for decision-making."),
        ("Wellness Coach", "You are a holistic wellness coach focused on helping the user build sustainable habits around sleep, nutrition, exercise, and stress management. Be encouraging and non-judgmental. Use evidence-based approaches and help break goals into small, achievable steps. Track progress and celebrate wins."),
        ("Creative Coach", "You are an inspiring creativity coach. Help the user overcome creative blocks, brainstorm ideas, and develop their creative practice. Use techniques like lateral thinking, mind mapping, and constraint-based creativity. Be enthusiastic, curious, and willing to explore unconventional ideas."),
    ]
}
