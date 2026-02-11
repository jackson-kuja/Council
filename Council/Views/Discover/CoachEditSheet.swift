import SwiftUI

struct CoachEditSheet: View {
    @StateObject private var viewModel: CoachEditViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showVoicePicker = false

    init(coach: Coach, config: UserCoachConfig?, connectedServices: [ConnectedService]) {
        _viewModel = StateObject(wrappedValue: CoachEditViewModel(
            coach: coach,
            config: config,
            connectedServices: connectedServices
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xxl) {
                    // Orb preview
                    orbPreview

                    // Name
                    nameSection

                    // Category
                    categorySection

                    // Orb Colors
                    colorSection

                    // Voice
                    voiceSection

                    // Conversation style
                    styleSection

                    // Tools
                    toolsSection
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Edit Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.save()
                            if viewModel.saveSuccess { dismiss() }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(AppColors.accent)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isSaving)
                    .foregroundColor(viewModel.hasChanges ? AppColors.accent : AppColors.textTertiary)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerSheet(
                    selectedVoiceId: viewModel.selectedVoiceId,
                    onSelect: { voice in
                        viewModel.selectedVoiceId = voice.id
                        viewModel.selectedVoiceName = voice.name
                        showVoicePicker = false
                    }
                )
            }
        }
    }

    // MARK: - Orb Preview

    private var orbPreview: some View {
        OrbAvatar(colors: viewModel.orbColorPair, size: 80)
            .frame(height: 90)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("NAME")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)

            TextField("Coach name", text: $viewModel.name)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("CATEGORY")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.xs) {
                ForEach(CoachCategory.allCases) { cat in
                    Button {
                        viewModel.category = cat
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 14))
                            Text(cat.displayName)
                                .font(AppTypography.bodySmall)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(viewModel.category == cat ? AppColors.accent : AppColors.textSecondary)
                        .background(viewModel.category == cat ? AppColors.accent.opacity(0.08) : AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .strokeBorder(
                                    viewModel.category == cat ? AppColors.accent.opacity(0.3) : AppColors.border,
                                    lineWidth: 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Orb Colors

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("ORB COLORS")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(AppColors.orbPalettes.enumerated()), id: \.offset) { index, palette in
                        let hexPair = orbPaletteHexes[index]
                        let isSelected = viewModel.orbColors == hexPair

                        Button {
                            viewModel.orbColors = hexPair
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.0, palette.1],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if isSelected {
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 2.5)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .shadow(color: isSelected ? palette.0.opacity(0.4) : .clear, radius: 4, y: 2)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("VOICE")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)

            Button {
                showVoicePicker = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedVoiceName.isEmpty ? "Select voice" : viewModel.selectedVoiceName)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        Text("Tap to change")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Tools

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("CONVERSATION STYLE")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)

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
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                Text(style.subtitle)
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                viewModel.expressiveStyle == style
                                    ? AppColors.accent.opacity(0.08)
                                    : AppColors.surface
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                    .strokeBorder(
                                        viewModel.expressiveStyle == style
                                            ? AppColors.accent.opacity(0.3)
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
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pace.displayName)
                                    .font(AppTypography.bodyMedium)
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.responsePace == pace
                                ? AppColors.accent.opacity(0.08)
                                : AppColors.surface
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .strokeBorder(
                                    viewModel.responsePace == pace
                                        ? AppColors.accent.opacity(0.3)
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
            }

            Toggle(isOn: $viewModel.quickReplies) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick replies")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Reply faster when pauses are short")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .tint(AppColors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("TOOLS")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)

            ForEach(ServiceType.allCases.filter(\.isAvailable)) { serviceType in
                let isConnected = viewModel.isServiceConnected(serviceType)
                let isEnabled = viewModel.isMCPEnabled(serviceType)

                HStack(spacing: 12) {
                    Image(systemName: serviceType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isConnected ? AppColors.accent : AppColors.textTertiary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(serviceType.displayName)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        if !isConnected {
                            Text("Connect in Settings")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { _ in viewModel.toggleMCP(serviceType: serviceType) }
                    ))
                    .labelsHidden()
                    .disabled(!isConnected)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                .opacity(isConnected ? 1 : 0.6)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Helpers

    /// Hex pairs matching AppColors.orbPalettes order
    private var orbPaletteHexes: [[String]] {
        [
            ["6366F1", "818CF8"],
            ["EC4899", "F472B6"],
            ["10B981", "34D399"],
            ["3B82F6", "60A5FA"],
            ["F97316", "FB923C"],
            ["8B5CF6", "A78BFA"],
            ["14B8A6", "2DD4BF"],
            ["F43F5E", "FB7185"],
        ]
    }
}

// MARK: - Voice Picker Sheet

struct VoicePickerSheet: View {
    let selectedVoiceId: String
    let onSelect: (VoiceOption) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var voices: [VoiceOption] = []
    @State private var isLoading = true

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                            ForEach(voices) { voice in
                                Button {
                                    onSelect(voice)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(voice.name)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(AppColors.textPrimary)

                                        if let descriptive = voice.descriptive {
                                            Text(descriptive)
                                                .font(AppTypography.captionLarge)
                                                .foregroundColor(AppColors.textTertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        selectedVoiceId == voice.id
                                            ? AppColors.accent.opacity(0.08)
                                            : AppColors.surface
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                            .strokeBorder(
                                                selectedVoiceId == voice.id
                                                    ? AppColors.accent.opacity(0.3)
                                                    : AppColors.border,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                                }
                            }
                        }
                        .padding(AppSpacing.lg)
                    }
                }
            }
            .background(AppColors.background)
            .navigationTitle("Choose Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .task {
                do {
                    voices = try await ElevenLabsAPIService.shared.listVoices()
                } catch {}
                isLoading = false
            }
        }
    }
}
