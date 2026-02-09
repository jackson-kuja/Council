import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var viewModel = ProfileViewModel()
    @State private var enabledModels = ModelPreferences.shared.enabledModels
    @State private var selectedVoiceModel = VoiceModelPreferences.shared.selectedModel
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xxl) {
                    // Profile header
                    profileHeader

                    // Subscription status
                    if !subscriptionService.isPremium {
                        upgradeRow
                    } else {
                        premiumBadge
                    }

                    // Connected services section
                    connectedServicesSection

                    // Personal context section
                    contextSection

                    // Models section
                    modelsSection

                    // Sign out
                    Button {
                        authViewModel.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(AppTypography.buttonSmall)
                        }
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppColors.error.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .strokeBorder(AppColors.error.opacity(0.2), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadProfile()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(trigger: .general)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Text(viewModel.profile.displayName.prefix(1).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(viewModel.profile.displayName)
                .font(AppTypography.titleLarge)
                .foregroundColor(AppColors.textPrimary)

            Text(viewModel.profile.email)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Subscription

    private var upgradeRow: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Premium")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Unlimited sessions, multi-coach, Notion & more")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(14)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var premiumBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)

            Text("Premium")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text("Active")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.success)
        }
        .padding(14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Connected Services Section

    private var connectedServicesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected Services")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Connect services to give your coaches access to tools")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }

            ForEach(ServiceType.allCases) { serviceType in
                let service = viewModel.connectedService(for: serviceType)
                let isConnected = service?.isConnected ?? false

                HStack(spacing: 12) {
                    Image(systemName: serviceType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isConnected ? AppColors.accent : AppColors.textTertiary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(serviceType.displayName)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        if isConnected, let workspaceName = service?.workspaceName, !workspaceName.isEmpty {
                            Text(workspaceName)
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textTertiary)
                        } else if !isConnected {
                            Text("Not connected")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    if viewModel.isConnectingService {
                        ProgressView()
                            .tint(AppColors.textTertiary)
                    } else if isConnected {
                        Button {
                            Task { await viewModel.disconnectService(serviceType) }
                        } label: {
                            Text("Disconnect")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.error)
                        }
                    } else {
                        Button {
                            if subscriptionService.isPremium {
                                Task {
                                    switch serviceType {
                                    case .notion:
                                        await viewModel.connectNotion()
                                    }
                                }
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if !subscriptionService.isPremium {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10))
                                }
                                Text("Connect")
                                    .font(AppTypography.captionLarge)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Models")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Choose which models appear during sessions")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Voice")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                ForEach(TTSVoiceModel.allCases) { model in
                    Button {
                        selectedVoiceModel = model
                        VoiceModelPreferences.shared.setSelectedModel(model)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimary)

                                Text(model.subtitle)
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textTertiary)
                            }

                            Spacer()

                            Image(systemName: selectedVoiceModel == model ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(
                                    selectedVoiceModel == model
                                        ? AppColors.accent
                                        : AppColors.textTertiary
                                )
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                    }
                }
            }

            ForEach(ModelProvider.allCases) { provider in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(provider.rawValue)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    ForEach(LLMModel.models(for: provider)) { model in
                        Button {
                            ModelPreferences.shared.toggle(model)
                            enabledModels = ModelPreferences.shared.enabledModels
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textPrimary)

                                    Text(model.subtitle)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textTertiary)
                                }

                                Spacer()

                                Image(systemName: enabledModels.contains(model) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(
                                        enabledModels.contains(model)
                                            ? AppColors.accent
                                            : AppColors.textTertiary
                                    )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Context Section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Context")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Shared with your coaches to personalize sessions")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if viewModel.saveSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Values
            ContextEditorSection(
                title: "Values",
                icon: "heart.fill",
                items: $viewModel.editingValues,
                newItem: $viewModel.newValue,
                placeholder: "Add a value (e.g. Growth)",
                onAdd: viewModel.addValue,
                onRemove: viewModel.removeValue
            )

            // Goals
            ContextEditorSection(
                title: "Goals",
                icon: "target",
                items: $viewModel.editingGoals,
                newItem: $viewModel.newGoal,
                placeholder: "Add a goal (e.g. Launch my startup)",
                onAdd: viewModel.addGoal,
                onRemove: viewModel.removeGoal
            )

            // Notes
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("Notes", systemImage: "note.text")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)

                TextEditor(text: $viewModel.editingNotes)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }

            // Save
            Button {
                Task { await viewModel.saveContext() }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save Context")
                            .font(AppTypography.buttonLarge)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppColors.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}
