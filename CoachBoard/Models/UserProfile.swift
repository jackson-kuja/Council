import Foundation

struct UserProfile: Codable, Identifiable {
    var id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var personalContext: PersonalContext
    var createdAt: Date

    static var empty: UserProfile {
        UserProfile(
            id: "",
            displayName: "",
            email: "",
            photoURL: nil,
            personalContext: .empty,
            createdAt: Date()
        )
    }
}

struct PersonalContext: Codable {
    var values: [String]
    var goals: [String]
    var notes: String

    static var empty: PersonalContext {
        PersonalContext(values: [], goals: [], notes: "")
    }

    var isEmpty: Bool {
        values.isEmpty && goals.isEmpty && notes.isEmpty
    }

    /// Formats context for injection into coach system prompts
    func formattedForPrompt(userName: String) -> String {
        var parts: [String] = []
        parts.append("--- User Context ---")
        parts.append("Name: \(userName)")

        if !values.isEmpty {
            parts.append("Values: \(values.joined(separator: ", "))")
        }
        if !goals.isEmpty {
            parts.append("Goals: \(goals.joined(separator: ", "))")
        }
        if !notes.isEmpty {
            parts.append("Additional Context: \(notes)")
        }

        return parts.joined(separator: "\n")
    }
}
