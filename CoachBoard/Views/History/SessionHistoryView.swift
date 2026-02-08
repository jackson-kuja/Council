import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionHistoryViewModel()
    @State private var selectedSession: CoachingSession?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.textSecondary)
                } else if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedSession) { session in
                TranscriptView(session: session)
            }
            .task {
                await viewModel.loadSessions()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("No sessions yet")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text("Start a coaching session from the Discover tab")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xxl)
    }

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.sessions) { session in
                    SessionRow(session: session)
                        .onTapGesture {
                            selectedSession = session
                        }
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}

struct SessionRow: View {
    let session: CoachingSession

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            Circle()
                .fill(AppColors.surface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "waveform")
                        .foregroundColor(AppColors.textPrimary)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.coachName)
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.sm) {
                    Text(session.formattedDate)
                    Text("  ")
                    Text(session.formattedDuration)
                }
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Transcript indicator
            HStack(spacing: 4) {
                Text("\(session.transcript.count)")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textTertiary)
                Image(systemName: "text.bubble")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}
