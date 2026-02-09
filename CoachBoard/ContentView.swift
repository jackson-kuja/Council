import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var selectedTab = 0
    @State private var sharedCoach: Coach?
    @State private var isLoadingSharedCoach = false
    @State private var paywallTrigger: PaywallTrigger?

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            CreateCoachView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(1)

            SessionHistoryView()
                .tabItem {
                    Label("Sessions", systemImage: "clock.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(AppColors.accent)
        .sheet(item: $sharedCoach) { coach in
            CoachDetailView(coach: coach)
        }
        .sheet(item: $paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
        .overlay {
            if isLoadingSharedCoach {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coachDeepLinkReceived)) { notification in
            guard let coachId = notification.userInfo?["coachId"] as? String else { return }
            handleSharedCoach(coachId: coachId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { notification in
            if let trigger = notification.userInfo?["trigger"] as? PaywallTrigger {
                paywallTrigger = trigger
            }
        }
    }

    private func handleSharedCoach(coachId: String) {
        // Check built-in coaches first (instant, no network)
        if let builtIn = Coach.builtInCoaches.first(where: { $0.id == coachId }) {
            sharedCoach = builtIn
            return
        }

        // Fetch from Firestore
        isLoadingSharedCoach = true
        Task {
            defer { isLoadingSharedCoach = false }
            if let coach = try? await FirebaseService.shared.fetchCoach(id: coachId) {
                sharedCoach = coach
            }
        }
    }
}

// MARK: - PaywallTrigger Identifiable conformance

extension PaywallTrigger: Identifiable {
    var id: String {
        switch self {
        case .multiCoach: return "multiCoach"
        case .notion: return "notion"
        case .customCoach: return "customCoach"
        case .sessionLimit: return "sessionLimit"
        case .continuity: return "continuity"
        case .flagshipModel: return "flagshipModel"
        case .general: return "general"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let showPaywall = Notification.Name("showPaywall")
}
