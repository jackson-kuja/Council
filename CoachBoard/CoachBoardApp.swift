import SwiftUI
import FirebaseCore
import FirebaseAuth
import RevenueCat

@main
struct CoachBoardApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var subscriptionService = SubscriptionService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        FirebaseApp.configure()
        SubscriptionService.shared.configure()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated && hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(subscriptionService)
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .environmentObject(authViewModel)
                    .environmentObject(subscriptionService)
                }
            }
            .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
                Task {
                    if isAuth, let uid = Auth.auth().currentUser?.uid {
                        await subscriptionService.login(userId: uid)
                    } else {
                        await subscriptionService.logout()
                    }
                }
            }
            .task {
                if authViewModel.isAuthenticated, let uid = Auth.auth().currentUser?.uid {
                    await subscriptionService.login(userId: uid)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                handleDeepLink(url)
            }
        }
    }

    private func configureAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = .black

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = .white
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = .black
    }

    private func handleDeepLink(_ url: URL) {
        // Coach deep link: coachboard://coach/{coachId}
        if let coachAction = CoachDeepLinkAction.from(url: url) {
            switch coachAction {
            case .open(let coachId):
                NotificationCenter.default.post(
                    name: .coachDeepLinkReceived,
                    object: nil,
                    userInfo: ["coachId": coachId]
                )
            }
            return
        }

        // Session deep link: coachboard://session/{action}
        guard let action = SessionDeepLinkAction.from(url: url) else { return }
        NotificationCenter.default.post(
            name: .sessionDeepLinkActionRequested,
            object: nil,
            userInfo: ["action": action.rawValue]
        )
    }
}
