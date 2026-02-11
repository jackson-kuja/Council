import SwiftUI

struct CreateCoachView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var viewModel = CreateCoachViewModel()
    @State private var showSuccess = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !subscriptionService.isPremium {
                    // Premium gate
                    premiumGate
                } else {
                    createFlow
                }
            }
            .background(AppColors.background)
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.large)
            .alert("Coach Created!", isPresented: $showSuccess) {
                Button("View in Council") {
                    viewModel.currentStep = 0
                    viewModel.name = ""
                    viewModel.description = ""
                    viewModel.systemPrompt = ""
                    viewModel.firstMessage = ""
                    viewModel.selectedVoice = nil
                    viewModel.speechSpeed = 1.0
                    viewModel.responsePace = .balanced
                    viewModel.quickReplies = false
                    viewModel.expressiveStyle = .natural
                    NotificationCenter.default.post(name: .switchToCouncilTab, object: nil)
                }
            } message: {
                Text("\(viewModel.name) is now live!")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(trigger: .customCoach)
            }
        }
    }

    // MARK: - Premium Gate

    private var premiumGate: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppColors.surfaceElevated)

            VStack(spacing: 8) {
                Text("Create Your Own Coach")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("Name it, tell it how to think, pick a voice, and share it with one link.")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button { showPaywall = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Upgrade to Premium")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppColors.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }

    // MARK: - Create Flow

    private var createFlow: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

                // Step content
                TabView(selection: $viewModel.currentStep) {
                    basicsStep.tag(0)
                    promptStep.tag(1)
                    voiceStep.tag(2)
                    modelStep.tag(3)
                    styleStep.tag(4)
                    finalStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)

                // Navigation buttons
                navigationButtons
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(0..<viewModel.totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= viewModel.currentStep ? AppColors.accent : AppColors.surfaceElevated)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Step 1: Basics

    private var basicsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                StepHeader(title: "Name & Description", subtitle: "Give your coach an identity")

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Name")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)

                    TextField("e.g. Momentum", text: $viewModel.name)
                        .font(AppTypography.bodyLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .strokeBorder(AppColors.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Description")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)

                    TextField("What does this coach help with?", text: $viewModel.description, axis: .vertical)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3...6)
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .strokeBorder(AppColors.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Category")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.xs) {
                        ForEach(CoachCategory.allCases) { category in
                            Button {
                                viewModel.category = category
                            } label: {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: category.icon)
                                    Text(category.displayName)
                                        .font(AppTypography.bodySmall)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(AppSpacing.sm)
                                .background(
                                    viewModel.category == category
                                        ? AppColors.accent.opacity(0.08)
                                        : AppColors.surface
                                )
                                .foregroundColor(
                                    viewModel.category == category
                                        ? AppColors.accent
                                        : AppColors.textSecondary
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                        .strokeBorder(
                                            viewModel.category == category
                                                ? AppColors.accent
                                                : AppColors.border,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2: System Prompt

    private var promptStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                StepHeader(title: "System Prompt", subtitle: "Define your coach's personality and expertise")

                // Templates
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Start from a template")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(CreateCoachViewModel.promptTemplates, id: \.0) { name, prompt in
                                Button {
                                    viewModel.systemPrompt = prompt
                                } label: {
                                    Text(name)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.accent)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, AppSpacing.xs)
                                        .background(AppColors.accent.opacity(0.08))
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(AppColors.accent.opacity(0.2), lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // Editor
                TextEditor(text: $viewModel.systemPrompt)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .padding(AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 3: Voice

    private var voiceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                StepHeader(title: "Voice", subtitle: "Choose how your coach sounds")

                if viewModel.isLoadingVoices {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.huge)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                        ForEach(viewModel.availableVoices) { voice in
                            VoiceCard(
                                voice: voice,
                                isSelected: viewModel.selectedVoice?.id == voice.id
                            ) {
                                viewModel.selectedVoice = voice
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .task {
                if viewModel.availableVoices.isEmpty {
                    await viewModel.loadVoices()
                }
            }
        }
    }

    // MARK: - Step 4: Model

    private var modelStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                StepHeader(title: "Model", subtitle: "Choose the brain behind your coach")

                ForEach(ModelProvider.allCases) { provider in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.xs) {
                            Text(provider.personalityLabel)
                                .font(AppTypography.captionLarge)
                                .foregroundColor(Color(hex: provider.labelColorHex))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: provider.labelColorHex).opacity(0.12))
                                .clipShape(Capsule())

                            Text(provider.rawValue)
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textTertiary)
                        }

                        ForEach(LLMModel.models(for: provider)) { model in
                            Button {
                                viewModel.selectedModel = model
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.displayName)
                                            .font(AppTypography.titleSmall)
                                            .foregroundColor(AppColors.textPrimary)

                                        Text(model.subtitle)
                                            .font(AppTypography.captionLarge)
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    if viewModel.selectedModel == model {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.accent)
                                    }
                                }
                                .padding(AppSpacing.md)
                                .background(
                                    viewModel.selectedModel == model
                                        ? AppColors.accent.opacity(0.08)
                                        : AppColors.surface
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                        .strokeBorder(
                                            viewModel.selectedModel == model
                                                ? AppColors.accent
                                                : AppColors.border,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    // MARK: - Step 5: Final

    private var styleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                StepHeader(
                    title: "Conversation Style",
                    subtitle: "Tune how your coach sounds and responds"
                )

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Voice style")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.xs) {
                        ForEach(CoachExpressiveStyle.allCases) { style in
                            Button {
                                viewModel.expressiveStyle = style
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(style.displayName)
                                        .font(AppTypography.titleSmall)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(style.subtitle)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.sm)
                                .background(
                                    viewModel.expressiveStyle == style
                                        ? AppColors.accent.opacity(0.08)
                                        : AppColors.surface
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                        .strokeBorder(
                                            viewModel.expressiveStyle == style
                                                ? AppColors.accent
                                                : AppColors.border,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Reply timing")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)

                    ForEach(CoachResponsePace.allCases) { pace in
                        Button {
                            viewModel.responsePace = pace
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pace.displayName)
                                        .font(AppTypography.titleSmall)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(pace.subtitle)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                if viewModel.responsePace == pace {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            .padding(AppSpacing.md)
                            .background(
                                viewModel.responsePace == pace
                                    ? AppColors.accent.opacity(0.08)
                                    : AppColors.surface
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                    .strokeBorder(
                                        viewModel.responsePace == pace
                                            ? AppColors.accent
                                            : AppColors.border,
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text("Speaking speed")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(viewModel.speechSpeed, specifier: "%.2f")x")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Slider(value: $viewModel.speechSpeed, in: 0.8...1.15, step: 0.05)
                        .tint(AppColors.accent)

                    HStack {
                        Text("Calmer")
                        Spacer()
                        Text("Faster")
                    }
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textTertiary)
                }

                Toggle(isOn: $viewModel.quickReplies) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick replies")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Start responses sooner when pauses are short")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .tint(AppColors.accent)
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .padding(AppSpacing.lg)
        }
    }

    // MARK: - Step 6: Final

    private var finalStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                StepHeader(title: "First Message", subtitle: "What does your coach say when you start a session?")

                TextField("e.g. Hey! Ready to make today count?", text: $viewModel.firstMessage, axis: .vertical)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2...4)
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))

                // Preview card
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Preview")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)

                    GradientCard(colors: viewModel.category.gradient) {
                        HStack(spacing: AppSpacing.md) {
                            OrbAvatar(
                                colors: (Color(hex: viewModel.selectedOrbColors[0]),
                                         Color(hex: viewModel.selectedOrbColors[1])),
                                size: 50
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.name.isEmpty ? "Coach Name" : viewModel.name)
                                    .font(AppTypography.titleSmall)
                                    .foregroundColor(AppColors.textPrimary)

                                Text(viewModel.description.isEmpty ? "Description" : viewModel.description)
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)

                                Text("\(viewModel.expressiveStyle.displayName) voice • \(viewModel.responsePace.displayName) timing")
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.error)
                }
            }
            .padding(AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: AppSpacing.md) {
            if viewModel.currentStep > 0 {
                Button {
                    viewModel.previousStep()
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
                if viewModel.currentStep == viewModel.totalSteps - 1 {
                    // Create
                    Task {
                        await viewModel.createCoach(creatorId: authViewModel.currentUserId ?? "")
                        if viewModel.createdCoach != nil {
                            showSuccess = true
                        }
                    }
                } else {
                    viewModel.nextStep()
                }
            } label: {
                Group {
                    if viewModel.isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(viewModel.currentStep == viewModel.totalSteps - 1 ? "Create Coach" : "Next")
                            .font(AppTypography.buttonLarge)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(viewModel.canProceed ? AppColors.accent : AppColors.surfaceElevated)
                .foregroundColor(viewModel.canProceed ? .white : AppColors.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .disabled(!viewModel.canProceed || viewModel.isCreating)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }
}

// MARK: - Step Header

struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.titleLarge)
                .foregroundColor(AppColors.textPrimary)

            Text(subtitle)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
