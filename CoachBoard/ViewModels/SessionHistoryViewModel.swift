import SwiftUI
import FirebaseAuth

@MainActor
class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [CoachingSession] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadSessions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await FirebaseService.shared.fetchSessions(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
