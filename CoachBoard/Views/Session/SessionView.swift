import SwiftUI
import ElevenLabs
import ElevenLabsComponents

struct SessionView: View {
    let coach: Coach
    let onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SessionViewModel
    @State private var showSettings = false
    @State private var showAddCoach = false
    @State private var sessionContentVisible = false

    init(coach: Coach, onDismiss: (() -> Void)? = nil) {
        self.coach = coach
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: SessionViewModel(coach: coach))
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .opacity(sessionContentVisible ? 1 : 0)
                    .offset(y: sessionContentVisible ? 0 : -12)

                Spacer()

                // The orb (hero-animated)
                    heroOrbView
                    .frame(height: 240)

                // State label
                stateLabel
                    .padding(.top, 16)
                    .opacity(sessionContentVisible ? 1 : 0)

                Spacer()

                // Transcript
                transcript
                    .padding(.bottom, 24)
                    .opacity(sessionContentVisible ? 1 : 0)
                    .offset(y: sessionContentVisible ? 0 : 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                sessionContentVisible = true
            }
        }
        .task {
            await viewModel.loadProfileAndStart()
        }
        .onDisappear {
            viewModel.cancelPendingStartup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .sheet(isPresented: $showSettings) {
            SessionSettingsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddCoach) {
            AddCoachSheet(viewModel: viewModel)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Coach name(s)
            Group {
                if viewModel.activeCoaches.count == 1 {
                    Text(coach.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                } else {
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.activeCoaches.enumerated()), id: \.element.id) { index, activeCoach in
                            Text(activeCoach.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(
                                    viewModel.speakingCoachId == activeCoach.id
                                        ? activeCoach.orbColorPair.0
                                        : AppColors.textTertiary
                                )
                            if index < viewModel.activeCoaches.count - 1 {
                                Text("·")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.speakingCoachId)
            .animation(.easeInOut(duration: 0.3), value: viewModel.activeCoaches.count)

            Spacer()

            Text(viewModel.formattedDuration)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.textTertiary)
                .padding(.trailing, 8)

            // Share
            ShareLink(
                item: coach.shareURL,
                subject: Text(coach.name),
                message: Text(coach.shareText)
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }
            .padding(.trailing, 6)

            // Add Coach button
            if viewModel.canAddCoach {
                Button {
                    if SubscriptionService.shared.isPremium {
                        showAddCoach = true
                    } else {
                        NotificationCenter.default.post(
                            name: .showPaywall,
                            object: nil,
                            userInfo: ["trigger": PaywallTrigger.multiCoach]
                        )
                    }
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surface)
                        .clipShape(Circle())
                }
                .padding(.trailing, 6)
            }

            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }
            .padding(.trailing, 6)

            // Close
            Button {
                closeSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Close

    private func closeSession() {
        Task { await viewModel.endSession() }

        if let onDismiss {
            // Hero dismiss: fade out content, then morph orb back
            withAnimation(.easeIn(duration: 0.2)) {
                sessionContentVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onDismiss()
            }
        } else {
            dismiss()
        }
    }

    // MARK: - State Label

    private var stateLabel: some View {
        Group {
            if viewModel.activeCoaches.count > 1,
               viewModel.agentState == "Speaking",
               let speakingId = viewModel.speakingCoachId,
               let speakingCoach = viewModel.activeCoaches.first(where: { $0.id == speakingId }) {
                Text("\(speakingCoach.name.lowercased()) speaking")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            } else {
                Text(viewModel.agentState.lowercased())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    // MARK: - Orb

    private var heroOrbView: some View {
        orbView
    }

    private var orbView: some View {
        Group {
            if let conversation = viewModel.conversation {
                if viewModel.activeCoaches.count == 1 {
                    OrbVisualizer(
                        inputTrack: conversation.inputTrack,
                        outputTrack: conversation.agentAudioTrack,
                        agentState: viewModel.visualizerState,
                        colors: coach.orbColorPair
                    )
                    .frame(width: 220, height: 220)
                } else {
                    multiCoachOrbView(conversation: conversation)
                }
            } else if viewModel.activeCoaches.count > 1 {
                multiCoachIdleOrbs
            } else {
                OrbAvatar(colors: coach.orbColorPair, size: 220)
                    .opacity(viewModel.isConnecting || viewModel.isAddingCoach ? 0.6 : 1)
            }
        }
    }

    @ViewBuilder
    private func multiCoachOrbView(conversation: Conversation) -> some View {
        let coaches = viewModel.activeCoaches
        let speakingId = viewModel.speakingCoachId

        ZStack {
            ForEach(Array(coaches.enumerated()), id: \.element.id) { index, activeCoach in
                let isSpeaking = speakingId == activeCoach.id
                let orbSize: CGFloat = isSpeaking ? 160 : 120
                let offset = multiCoachOffset(index: index, count: coaches.count)

                Group {
                    if isSpeaking && viewModel.agentState == "Speaking" {
                        OrbVisualizer(
                            inputTrack: conversation.inputTrack,
                            outputTrack: conversation.agentAudioTrack,
                            agentState: .speaking,
                            colors: activeCoach.orbColorPair
                        )
                        .frame(width: orbSize, height: orbSize)
                    } else {
                        OrbAvatar(colors: activeCoach.orbColorPair, size: orbSize)
                            .opacity(isSpeaking ? 1.0 : 0.7)
                    }
                }
                .offset(x: offset.x, y: offset.y)
                .zIndex(isSpeaking ? 10 : Double(index))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: speakingId)
            }
        }
        .frame(width: 280, height: 220)
    }

    private var multiCoachIdleOrbs: some View {
        let coaches = viewModel.activeCoaches
        return ZStack {
            ForEach(Array(coaches.enumerated()), id: \.element.id) { index, activeCoach in
                let offset = multiCoachOffset(index: index, count: coaches.count)
                OrbAvatar(colors: activeCoach.orbColorPair, size: 120)
                    .opacity(viewModel.isAddingCoach ? 0.5 : 0.8)
                    .offset(x: offset.x, y: offset.y)
            }
        }
        .frame(width: 280, height: 220)
    }

    private func multiCoachOffset(index: Int, count: Int) -> CGPoint {
        switch count {
        case 2:
            return index == 0 ? CGPoint(x: -50, y: 0) : CGPoint(x: 50, y: 0)
        case 3:
            switch index {
            case 0: return CGPoint(x: 0, y: -30)
            case 1: return CGPoint(x: -55, y: 35)
            case 2: return CGPoint(x: 55, y: 35)
            default: return .zero
            }
        default:
            return .zero
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.messages) { message in
                        HStack {
                            if message.role == .user { Spacer(minLength: 60) }

                            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                                // Coach name label for agent messages
                                if message.role == .agent,
                                   let coachName = message.coachName {
                                    Text(coachName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(coachColor(for: message.coachId))
                                }

                                Text(message.content)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(
                                        message.role == .user
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        message.role == .user
                                            ? AppColors.surface
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            if message.role == .agent { Spacer(minLength: 60) }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 180)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func coachColor(for coachId: String?) -> Color {
        guard let coachId,
              let activeCoach = viewModel.activeCoaches.first(where: { $0.id == coachId }) else {
            return AppColors.textTertiary
        }
        return activeCoach.orbColorPair.0
    }
}

// MARK: - Add Coach Sheet

struct AddCoachSheet: View {
    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    private var availableCoaches: [Coach] {
        let activeIds = Set(viewModel.activeCoaches.map(\.id))
        return Coach.builtInCoaches.filter { !activeIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(availableCoaches) { coach in
                        Button {
                            Task {
                                dismiss()
                                await viewModel.addCoach(coach)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                OrbAvatar(colors: coach.orbColorPair, size: 48)
                                    .frame(width: 48, height: 48)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(coach.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)

                                    Text(coach.description)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppColors.accent)
                            }
                            .padding(14)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(24)
            }
            .background(AppColors.background)
            .navigationTitle("Add Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Settings Sheet

struct SessionSettingsSheet: View {
    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel: LLMModel
    @State private var selectedVoiceModel: TTSVoiceModel
    @State private var isApplying = false

    private var availableModels: [LLMModel] {
        ModelPreferences.shared.enabledModels
    }

    private var availableVoiceModels: [TTSVoiceModel] {
        TTSVoiceModel.allCases
    }

    private var hasChanges: Bool {
        selectedModel != viewModel.coach.llmModel ||
            selectedVoiceModel != viewModel.selectedVoiceModel
    }

    init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
        _selectedModel = State(initialValue: viewModel.coach.llmModel)
        _selectedVoiceModel = State(initialValue: viewModel.selectedVoiceModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("AI Model")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            ForEach(availableModels) { model in
                                Button {
                                    selectedModel = model
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(AppColors.textPrimary)

                                            Text(model.provider.rawValue)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.textTertiary)
                                        }

                                        Spacer()

                                        if selectedModel == model {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(AppColors.accent)
                                        } else {
                                            Circle()
                                                .strokeBorder(AppColors.border, lineWidth: 1.5)
                                                .frame(width: 18, height: 18)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(AppColors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Voice Model")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            ForEach(availableVoiceModels) { model in
                                Button {
                                    selectedVoiceModel = model
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(AppColors.textPrimary)

                                            Text(model.subtitle)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.textTertiary)
                                        }

                                        Spacer()

                                        if selectedVoiceModel == model {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(AppColors.accent)
                                        } else {
                                            Circle()
                                                .strokeBorder(AppColors.border, lineWidth: 1.5)
                                                .frame(width: 18, height: 18)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(AppColors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    .padding(24)
                }

                // Apply button
                Button {
                    Task {
                        isApplying = true
                        await viewModel.applySettings(
                            model: selectedModel,
                            voiceModel: selectedVoiceModel
                        )
                        isApplying = false
                        dismiss()
                    }
                } label: {
                    Group {
                        if isApplying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Apply")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        hasChanges ? AppColors.accent : AppColors.surfaceElevated
                    )
                    .foregroundColor(
                        hasChanges ? .white : AppColors.textTertiary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!hasChanges || isApplying)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppColors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
