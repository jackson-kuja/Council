import SwiftUI
import FirebaseAuth
import AuthenticationServices

// MARK: - Title Text Cascade Effect

struct TitleTextRenderer: TextRenderer, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let slices = layout.flatMap({ $0 }).flatMap({ $0 })

        for (index, slice) in slices.enumerated() {
            let sliceProgressIndex = CGFloat(slices.count) * progress
            let sliceProgress = max(min(sliceProgressIndex / CGFloat(index + 1), 1), 0)

            ctx.addFilter(.blur(radius: 5 - (5 * sliceProgress)))
            ctx.opacity = sliceProgress
            ctx.translateBy(x: 0, y: 5 - (5 * sliceProgress))
            ctx.draw(slice, options: .disablesSubpixelQuantization)
        }
    }
}

// MARK: - Blur / Opacity Reveal

extension View {
    func blurRevealEffect(_ show: Bool) -> some View {
        self
            .blur(radius: show ? 0 : 2)
            .opacity(show ? 1 : 0)
            .scaleEffect(show ? 1 : 0.9)
    }
}

// MARK: - Orbiting Orbs Hero

struct OrbitingOrbsView: View {
    private let coaches = Coach.builtInCoaches
    private let orbitRadius: CGFloat = 88
    private let orbSize: CGFloat = 54

    @State private var startTime: Date?

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = startTime.map { context.date.timeIntervalSince($0) } ?? 0
            let angle = elapsed * (360.0 / 22.0)

            ZStack {
                ForEach(Array(coaches.enumerated()), id: \.element.id) { index, coach in
                    let count = Double(coaches.count)
                    let orbAngle = angle + Double(index) * (360.0 / count)
                    let radians = orbAngle * .pi / 180

                    let x = cos(radians) * Double(orbitRadius)
                    let yOrbit = sin(radians) * Double(orbitRadius) * 0.38
                    let bob = sin(elapsed * 1.4 + Double(index) * 1.1) * 3.5
                    let y = yOrbit + bob

                    let depth = sin(radians)
                    let normalizedDepth = (depth + 1.0) / 2.0
                    let depthScale = 0.55 + 0.45 * normalizedDepth
                    let depthOpacity = 0.3 + 0.7 * normalizedDepth

                    let entranceDelay = Double(index) * 0.13
                    let rawProgress = min(1.0, max(0.0, (elapsed - entranceDelay) / 0.55))
                    let eased = 1.0 - pow(1.0 - rawProgress, 3.0)

                    OrbAvatar(colors: coach.orbColorPair, size: orbSize)
                        .scaleEffect(depthScale * eased)
                        .opacity(depthOpacity * eased)
                        .offset(x: x * eased, y: y * eased)
                        .zIndex(depth)
                }
            }
        }
        .frame(width: orbitRadius * 2 + orbSize + 24, height: orbitRadius * 0.76 + orbSize + 24)
        .onAppear { startTime = Date() }
    }
}

// MARK: - Onboarding Flow

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var values: [String] = []
    @State private var goals: [String] = []
    @State private var newValue = ""
    @State private var newGoal = ""
    @State private var selectedCoach: Coach?
    @State private var isSaving = false

    // Welcome entrance animation
    @State private var welcomeAnimated = false
    @State private var titleProgress: CGFloat = 0

    // Apple Sign In
    @State private var appleSignInCoordinator: AppleSignInCoordinator?

    private let totalSteps = 3
    private let coaches = Coach.builtInCoaches

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.top, AppSpacing.sm)

            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                contextStep.tag(1)
                coachStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            navigationButtons
        }
        .background(AppColors.background)
        .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
            if isAuth && currentStep == 0 {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 1 }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? AppColors.accent : AppColors.surfaceElevated)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: AppSpacing.xxxl) {
            // Orbiting orbs — proportional vertical space like reference
            OrbitingOrbsView()
                .containerRelativeFrame(.vertical) { value, _ in
                    value * 0.42
                }
                .visualEffect { [welcomeAnimated] content, proxy in
                    content
                        .offset(y: !welcomeAnimated ? -(proxy.size.height + 200) : 0)
                }

            // Title block — tight VStack(spacing: 4) matching reference
            VStack(spacing: 4) {
                Text("Welcome to")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .blurRevealEffect(welcomeAnimated)

                Group {
                    if #available(iOS 18, *) {
                        Text("Council")
                            .font(.largeTitle.bold())
                            .foregroundColor(AppColors.textPrimary)
                            .textRenderer(TitleTextRenderer(progress: titleProgress))
                    } else {
                        Text("Council")
                            .font(.largeTitle.bold())
                            .foregroundColor(AppColors.textPrimary)
                            .blurRevealEffect(welcomeAnimated)
                    }
                }
                .padding(.bottom, 12)

                Text("Your AI coaches learn who you are,\nwhat you care about, and how to help.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.textSecondary)
                    .blurRevealEffect(welcomeAnimated)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.error)
                        .padding(.top, 8)
                }
            }
        }
        .safeAreaPadding(15)
        .task {
            try? await Task.sleep(for: .seconds(0.35))

            withAnimation(.smooth(duration: 0.75, extraBounce: 0)) {
                welcomeAnimated = true
            }

            withAnimation(.smooth(duration: 2.5, extraBounce: 0).delay(0.3)) {
                titleProgress = 1
            }
        }
    }

    // MARK: - Step 2: Personal Context

    private var contextStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("A little about you")
                        .font(AppTypography.displaySmall)
                        .foregroundColor(AppColors.textPrimary)

                    Text("This helps your coaches give relevant, personalized advice. You can always update this later.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Values
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("What do you value?", systemImage: "heart.fill")
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)

                    FlowLayout(spacing: AppSpacing.xs) {
                        ForEach(valueSuggestions, id: \.self) { suggestion in
                            let isSelected = values.contains(suggestion)
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isSelected {
                                        values.removeAll { $0 == suggestion }
                                    } else {
                                        values.append(suggestion)
                                    }
                                }
                            } label: {
                                Text(suggestion)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(isSelected ? AppColors.accent : AppColors.surface)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    HStack(spacing: AppSpacing.xs) {
                        TextField("Add your own...", text: $newValue)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimary)
                            .onSubmit { addValue() }

                        Button { addValue() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppColors.accent)
                        }
                        .disabled(newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))

                    if !customValues.isEmpty {
                        FlowLayout(spacing: AppSpacing.xs) {
                            ForEach(Array(customValues.enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 4) {
                                    Text(item)
                                        .font(AppTypography.bodySmall)
                                        .foregroundColor(.white)

                                    Button {
                                        withAnimation { values.removeAll { $0 == item } }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.accent)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Goals
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("What are you working toward?", systemImage: "target")
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)

                    FlowLayout(spacing: AppSpacing.xs) {
                        ForEach(goalSuggestions, id: \.self) { suggestion in
                            let isSelected = goals.contains(suggestion)
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isSelected {
                                        goals.removeAll { $0 == suggestion }
                                    } else {
                                        goals.append(suggestion)
                                    }
                                }
                            } label: {
                                Text(suggestion)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(isSelected ? AppColors.accent : AppColors.surface)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    HStack(spacing: AppSpacing.xs) {
                        TextField("Add your own...", text: $newGoal)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimary)
                            .onSubmit { addGoal() }

                        Button { addGoal() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppColors.accent)
                        }
                        .disabled(newGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))

                    if !customGoals.isEmpty {
                        FlowLayout(spacing: AppSpacing.xs) {
                            ForEach(Array(customGoals.enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 4) {
                                    Text(item)
                                        .font(AppTypography.bodySmall)
                                        .foregroundColor(.white)

                                    Button {
                                        withAnimation { goals.removeAll { $0 == item } }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.accent)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    // MARK: - Step 3: Pick a Coach

    private var coachStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Pick your first coach")
                        .font(AppTypography.displaySmall)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Tap a coach to start your first session. You can explore all coaches later.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    spacing: 20
                ) {
                    ForEach(coaches) { coach in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCoach = selectedCoach?.id == coach.id ? nil : coach
                            }
                        } label: {
                            VStack(spacing: AppSpacing.sm) {
                                OrbAvatar(colors: coach.orbColorPair, size: 80)

                                VStack(spacing: 2) {
                                    Text(coach.name)
                                        .font(AppTypography.titleSmall)
                                        .foregroundColor(AppColors.textPrimary)

                                    Text(coach.category.displayName)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textTertiary)
                                }

                                Text(coach.description)
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedCoach?.id == coach.id
                                    ? AppColors.accent.opacity(0.06)
                                    : AppColors.surface
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                                    .strokeBorder(
                                        selectedCoach?.id == coach.id
                                            ? AppColors.accent
                                            : AppColors.border,
                                        lineWidth: selectedCoach?.id == coach.id ? 2 : 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: AppSpacing.md) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(AppTypography.buttonSmall)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppColors.surface)
                        .foregroundColor(AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .strokeBorder(AppColors.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
            }

            Button {
                if currentStep == 0 {
                    triggerAppleSignIn()
                } else if currentStep == totalSteps - 1 {
                    completeOnboarding()
                } else {
                    withAnimation { currentStep += 1 }
                }
            } label: {
                Group {
                    if isSaving || authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(buttonTitle)
                            .font(AppTypography.buttonLarge)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppColors.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .disabled(isSaving || authViewModel.isLoading)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
        .blurRevealEffect(currentStep == 0 ? welcomeAnimated : true)
    }

    private var buttonTitle: String {
        switch currentStep {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2: return selectedCoach != nil ? "Start with \(selectedCoach!.name)" : "Skip for Now"
        default: return "Continue"
        }
    }

    // MARK: - Data

    private let valueSuggestions = [
        "Growth", "Focus", "Balance", "Discipline",
        "Creativity", "Health", "Authenticity", "Impact"
    ]

    private let goalSuggestions = [
        "Build better habits", "Launch a project", "Get promoted",
        "Improve fitness", "Reduce stress", "Learn a new skill",
        "Start a business", "Write more"
    ]

    private var customValues: [String] {
        values.filter { !valueSuggestions.contains($0) }
    }

    private var customGoals: [String] {
        goals.filter { !goalSuggestions.contains($0) }
    }

    // MARK: - Apple Sign In

    private func triggerAppleSignIn() {
        if authViewModel.isAuthenticated {
            withAnimation(.easeInOut(duration: 0.3)) { currentStep = 1 }
            return
        }
        let coordinator = AppleSignInCoordinator(authViewModel: authViewModel)
        appleSignInCoordinator = coordinator
        coordinator.startSignIn()
    }

    // MARK: - Actions

    private func addValue() {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !values.contains(trimmed) else { return }
        withAnimation { values.append(trimmed) }
        newValue = ""
    }

    private func addGoal() {
        let trimmed = newGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !goals.contains(trimmed) else { return }
        withAnimation { goals.append(trimmed) }
        newGoal = ""
    }

    private func completeOnboarding() {
        isSaving = true

        Task {
            if !values.isEmpty || !goals.isEmpty {
                if let userId = Auth.auth().currentUser?.uid {
                    let context = PersonalContext(values: values, goals: goals, notes: "")
                    try? await FirebaseService.shared.updatePersonalContext(userId: userId, context: context)
                }
            }

            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

            await MainActor.run {
                isSaving = false
                onComplete()
            }
        }
    }
}

// MARK: - Apple Sign In Coordinator

private class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let authViewModel: AuthViewModel

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    func startSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = authViewModel.startSignInWithApple()

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            authViewModel.handleSignInWithApple(result: .success(authorization))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            authViewModel.handleSignInWithApple(result: .failure(error))
        }
    }
}
