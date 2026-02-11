import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var viewModel = ProfileViewModel()
    @State private var enabledModels = ModelPreferences.shared.enabledModels
    @State private var showPaywall = false
    @State private var showModels = false
    @State private var showComingSoon = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                        .padding(.bottom, 28)

                    VStack(spacing: 24) {
                        subscriptionSection
                        connectedServicesSection
                        contextSection
                        modelsSection
                        signOutRow
                    }
                }
                .padding(.bottom, 40)
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
            .alert("Coming Soon", isPresented: $showComingSoon) {
                Button("OK") {}
            } message: {
                Text("This integration is coming soon. We'll let you know when it's ready.")
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            OrbAvatar(
                colors: AppColors.orbPalettes[0],
                size: 72
            )

            VStack(spacing: 3) {
                Text(viewModel.profile.displayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)

                Text(viewModel.profile.email)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        ProfileCardGroup {
            if !subscriptionService.isPremium {
                Button { showPaywall = true } label: {
                    ProfileRow {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Upgrade to Premium")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)

                            Text("Unlimited sessions, multi-coach & more")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            } else {
                ProfileRow {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 30, height: 30)
                        .background(AppColors.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Premium")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text("Active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.success.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Connected Services

    private var connectedServicesSection: some View {
        ProfileSection(title: "Integrations") {
            ProfileCardGroup {
                ForEach(Array(ServiceType.allCases.enumerated()), id: \.element.id) { index, serviceType in
                    let service = viewModel.connectedService(for: serviceType)
                    let isConnected = service?.isConnected ?? false

                    if index > 0 {
                        Divider().padding(.leading, 54)
                    }

                    ProfileRow {
                        Image(systemName: serviceType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(isConnected ? .white : AppColors.textTertiary)
                            .frame(width: 30, height: 30)
                            .background(isConnected ? AppColors.accent : AppColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(serviceType.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)

                            if isConnected, let ws = service?.workspaceName, !ws.isEmpty {
                                Text(ws)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }

                        Spacer()

                        if !serviceType.isAvailable {
                            Button {
                                showComingSoon = true
                            } label: {
                                Text("Connect")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(AppColors.accent)
                                    .clipShape(Capsule())
                            }
                        } else if viewModel.isConnectingService {
                            ProgressView()
                                .tint(AppColors.textTertiary)
                        } else if isConnected {
                            Button {
                                Task { await viewModel.disconnectService(serviceType) }
                            } label: {
                                Text("Disconnect")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.error)
                            }
                        } else {
                            Button {
                                if subscriptionService.isPremium {
                                    Task {
                                        switch serviceType {
                                        case .notion:
                                            await viewModel.connectNotion()
                                        default:
                                            break
                                        }
                                    }
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    if !subscriptionService.isPremium {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 8))
                                    }
                                    Text("Connect")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(AppColors.accent)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Context Section

    private var contextSection: some View {
        ProfileSection(title: "Personal Context") {
            VStack(spacing: 10) {
                ContextEditorSection(
                    title: "Values",
                    icon: "heart.fill",
                    items: $viewModel.editingValues,
                    newItem: $viewModel.newValue,
                    placeholder: "Add a value (e.g. Growth)",
                    onAdd: viewModel.addValue,
                    onRemove: viewModel.removeValue
                )

                ContextEditorSection(
                    title: "Goals",
                    icon: "target",
                    items: $viewModel.editingGoals,
                    newItem: $viewModel.newGoal,
                    placeholder: "Add a goal (e.g. Launch my startup)",
                    onAdd: viewModel.addGoal,
                    onRemove: viewModel.removeGoal
                )

                VStack(alignment: .leading, spacing: 6) {
                    Label("Notes", systemImage: "note.text")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    TextEditor(text: $viewModel.editingNotes)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .padding(10)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    Task { await viewModel.saveContext() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            if viewModel.saveSuccess {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text(viewModel.saveSuccess ? "Saved" : "Save Context")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(viewModel.saveSuccess ? AppColors.success : AppColors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.saveSuccess)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProfileSection(title: "Models") {
                ProfileCardGroup {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showModels.toggle()
                        }
                    } label: {
                        ProfileRow {
                            Image(systemName: "cpu")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(AppColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("Voice & AI Models")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                                .rotationEffect(.degrees(showModels ? 90 : 0))
                        }
                    }
                }
            }

            if showModels {
                VStack(spacing: 16) {
                    // AI models by provider
                    ForEach(ModelProvider.allCases) { provider in
                        modelGroup(title: provider.rawValue) {
                            ForEach(Array(LLMModel.models(for: provider).enumerated()), id: \.element.id) { index, model in
                                if index > 0 { Divider().padding(.leading, 16) }
                                Button {
                                    ModelPreferences.shared.toggle(model)
                                    enabledModels = ModelPreferences.shared.enabledModels
                                } label: {
                                    modelRow(
                                        name: model.displayName,
                                        detail: model.subtitle,
                                        isSelected: enabledModels.contains(model)
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func modelGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)

            VStack(spacing: 0) {
                content()
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func modelRow(name: String, detail: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? AppColors.accent : AppColors.border)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Sign Out

    private var signOutRow: some View {
        ProfileCardGroup {
            Button {
                authViewModel.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.error)
                    Spacer()
                }
                .padding(.vertical, 13)
            }
        }
    }
}

// MARK: - Profile Building Blocks

private struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)
                .padding(.horizontal, 20)

            content()
        }
    }
}

private struct ProfileCardGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }
}

private struct ProfileRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
