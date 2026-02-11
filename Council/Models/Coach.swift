import Foundation
import SwiftUI

struct Coach: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var category: CoachCategory
    var systemPrompt: String
    var firstMessage: String
    var voiceId: String
    var voiceName: String
    var llmModel: LLMModel
    var speechSpeed: Double
    var responsePace: CoachResponsePace
    var quickReplies: Bool
    var expressiveStyle: CoachExpressiveStyle
    var elevenlabsAgentId: String
    var creatorId: String
    var isPublic: Bool
    var tags: [String]
    var usageCount: Int
    var orbColors: [String] // hex pairs e.g. ["CADCFC", "A0B9D1"]
    var isFeatured: Bool
    var createdAt: Date

    var voiceLabel: String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    var orbColorPair: (Color, Color) {
        guard orbColors.count >= 2 else {
            return AppColors.orbPalettes[0]
        }
        return (Color(hex: orbColors[0]), Color(hex: orbColors[1]))
    }

    var gradient: LinearGradient {
        let (start, end) = AppColors.gradientForCategory(category.rawValue)
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var expressiveTagNames: [String] {
        expressiveStyle.suggestedAudioTags.map(\.tag)
    }
}

enum CoachResponsePace: String, Codable, CaseIterable, Identifiable {
    case thoughtful
    case balanced
    case snappy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thoughtful: return "Thoughtful"
        case .balanced: return "Balanced"
        case .snappy: return "Snappy"
        }
    }

    var subtitle: String {
        switch self {
        case .thoughtful: return "Waits a bit longer before replying"
        case .balanced: return "Natural conversational timing"
        case .snappy: return "Replies quickly when pauses are short"
        }
    }

    var turnEagerness: String {
        switch self {
        case .thoughtful: return "patient"
        case .balanced: return "normal"
        case .snappy: return "eager"
        }
    }
}

enum CoachExpressiveStyle: String, Codable, CaseIterable, Identifiable {
    case natural
    case warm
    case calm
    case confident
    case playful
    case energetic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .warm: return "Warm"
        case .calm: return "Calm"
        case .confident: return "Confident"
        case .playful: return "Playful"
        case .energetic: return "Energetic"
        }
    }

    var subtitle: String {
        switch self {
        case .natural: return "Neutral delivery, no extra styling"
        case .warm: return "Supportive and empathetic tone"
        case .calm: return "Steady, grounded, and composed"
        case .confident: return "Clear, direct, and assertive"
        case .playful: return "Light and lively"
        case .energetic: return "High energy and momentum"
        }
    }

    var suggestedAudioTags: [CoachAudioTag] {
        switch self {
        case .natural:
            return []
        case .warm:
            return [
                CoachAudioTag(tag: "warm", description: "Use when offering support"),
                CoachAudioTag(tag: "empathetic", description: "Use when discussing emotions"),
            ]
        case .calm:
            return [
                CoachAudioTag(tag: "calm", description: "Use for grounding moments"),
                CoachAudioTag(tag: "steady", description: "Use when clarifying next steps"),
            ]
        case .confident:
            return [
                CoachAudioTag(tag: "confident", description: "Use when giving direction"),
                CoachAudioTag(tag: "direct", description: "Use for high-stakes decisions"),
            ]
        case .playful:
            return [
                CoachAudioTag(tag: "playful", description: "Use for creative exploration"),
                CoachAudioTag(tag: "light", description: "Use to keep energy positive"),
            ]
        case .energetic:
            return [
                CoachAudioTag(tag: "energetic", description: "Use when motivating action"),
                CoachAudioTag(tag: "upbeat", description: "Use to keep momentum high"),
            ]
        }
    }
}

struct CoachAudioTag: Codable, Hashable {
    let tag: String
    let description: String?
}

enum CoachCategory: String, Codable, CaseIterable, Identifiable {
    case productivity
    case mindset
    case career
    case health
    case creativity
    case custom

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .productivity: return "bolt.fill"
        case .mindset: return "brain.head.profile"
        case .career: return "briefcase.fill"
        case .health: return "heart.fill"
        case .creativity: return "paintbrush.fill"
        case .custom: return "sparkles"
        }
    }

    var gradient: (Color, Color) {
        AppColors.gradientForCategory(rawValue)
    }
}

enum ModelProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case google = "Google"

    var id: String { rawValue }

    var personalityLabel: String {
        switch self {
        case .openAI: return "Friendly"
        case .anthropic: return "Sociable"
        case .google: return "Well-Rounded"
        }
    }

    var labelColorHex: String {
        switch self {
        case .openAI: return "10A37F"
        case .anthropic: return "D97757"
        case .google: return "4285F4"
        }
    }
}

enum LLMModel: String, Codable, CaseIterable, Identifiable {
    // OpenAI
    case gpt5_2 = "gpt-5.2"
    case gpt5_1 = "gpt-5.1"
    case gpt5 = "gpt-5"
    case gpt5Mini = "gpt-5-mini"
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    // Anthropic
    case claudeSonnet4_5 = "claude-sonnet-4-5"
    case claudeSonnet4 = "claude-sonnet-4"
    case claudeHaiku = "claude-haiku-4-5"
    // Google
    case gemini3Pro = "gemini-3-pro-preview"
    case gemini3Flash = "gemini-3-flash-preview"
    case gemini25Flash = "gemini-2.5-flash"

    var id: String { rawValue }

    var provider: ModelProvider {
        switch self {
        case .gpt5_2, .gpt5_1, .gpt5, .gpt5Mini, .gpt4o, .gpt4oMini: return .openAI
        case .claudeSonnet4_5, .claudeSonnet4, .claudeHaiku: return .anthropic
        case .gemini3Pro, .gemini3Flash, .gemini25Flash: return .google
        }
    }

    var isFlagship: Bool {
        switch self {
        case .gpt5_2, .claudeSonnet4_5, .gemini3Pro: return true
        default: return false
        }
    }

    static var flagships: [LLMModel] {
        allCases.filter { $0.isFlagship }
    }

    static func models(for provider: ModelProvider) -> [LLMModel] {
        allCases.filter { $0.provider == provider }
    }

    var displayName: String {
        switch self {
        case .gpt5_2: return "GPT-5.2"
        case .gpt5_1: return "GPT-5.1"
        case .gpt5: return "GPT-5"
        case .gpt5Mini: return "GPT-5 Mini"
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .claudeSonnet4_5: return "Claude Sonnet 4.5"
        case .claudeSonnet4: return "Claude Sonnet 4"
        case .claudeHaiku: return "Claude Haiku 4.5"
        case .gemini3Pro: return "Gemini 3 Pro"
        case .gemini3Flash: return "Gemini 3 Flash"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        }
    }

    var subtitle: String {
        switch self {
        case .gpt5_2: return "Latest, most capable"
        case .gpt5_1: return "Powerful reasoning"
        case .gpt5: return "Strong all-rounder"
        case .gpt5Mini: return "Fast and capable"
        case .gpt4o: return "Proven, reliable"
        case .gpt4oMini: return "Quick responses"
        case .claudeSonnet4_5: return "Nuanced, thoughtful"
        case .claudeSonnet4: return "Balanced Claude"
        case .claudeHaiku: return "Ultra-fast Claude"
        case .gemini3Pro: return "Google's best"
        case .gemini3Flash: return "Fast Gemini"
        case .gemini25Flash: return "Low latency"
        }
    }
}

// MARK: - Model Preferences

class ModelPreferences {
    static let shared = ModelPreferences()
    private let key = "enabledModelIds"

    private init() {}

    var enabledModels: [LLMModel] {
        guard let ids = UserDefaults.standard.stringArray(forKey: key) else {
            return LLMModel.flagships
        }
        let models = ids.compactMap { LLMModel(rawValue: $0) }
        return models.isEmpty ? LLMModel.flagships : models
    }

    func isEnabled(_ model: LLMModel) -> Bool {
        enabledModels.contains(model)
    }

    func toggle(_ model: LLMModel) {
        var current = Set(enabledModels)
        if current.contains(model) {
            current.remove(model)
            if current.isEmpty { current.insert(model) } // keep at least one
        } else {
            current.insert(model)
        }
        UserDefaults.standard.set(
            LLMModel.allCases.filter { current.contains($0) }.map(\.rawValue),
            forKey: key
        )
    }
}

// MARK: - Sharing

extension Coach {
    var shareURL: URL {
        URL(string: "https://council-coaching.web.app/coach/\(id)")!
    }

    var shareText: String {
        "\(name) — \(description)"
    }
}
