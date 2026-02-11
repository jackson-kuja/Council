import SwiftUI
import FirebaseAuth

@MainActor
class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [CoachingSession] = []
    @Published var coaches: [String: Coach] = [:]
    @Published var isLoading = false
    @Published var error: String?

    func loadSessions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await FirebaseService.shared.fetchSessions(userId: userId)

            // Load all coaches so we can resolve orb colors for custom coaches
            var coachMap: [String: Coach] = [:]
            for coach in Coach.builtInCoaches {
                coachMap[coach.id] = coach
            }
            if let firestoreCoaches = try? await FirebaseService.shared.fetchCoaches() {
                for coach in firestoreCoaches {
                    coachMap[coach.id] = coach
                }
            }
            coaches = coachMap
        } catch {
            self.error = error.localizedDescription
        }
    }
}
