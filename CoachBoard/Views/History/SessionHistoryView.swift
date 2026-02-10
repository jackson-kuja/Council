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

            Text("Start a coaching session from the Council tab")
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

    private var allCoachNames: String {
        let names = [session.coachName] + session.additionalCoachNames
        return names.joined(separator: " + ")
    }

    private var coachOrbs: [(String, (Color, Color))] {
        var result: [(String, (Color, Color))] = []
        // Primary coach
        if let coach = Coach.builtInCoaches.first(where: { $0.id == session.coachId }) {
            result.append((coach.id, coach.orbColorPair))
        } else {
            result.append((session.coachId, AppColors.orbPalettes[0]))
        }
        // Additional coaches
        for additionalId in session.additionalCoachIds {
            if let coach = Coach.builtInCoaches.first(where: { $0.id == additionalId }) {
                result.append((coach.id, coach.orbColorPair))
            } else {
                let index = abs(additionalId.hashValue) % AppColors.orbPalettes.count
                result.append((additionalId, AppColors.orbPalettes[index]))
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Coach orb(s)
            ZStack {
                if coachOrbs.count == 1 {
                    OrbAvatar(colors: coachOrbs[0].1, size: 44)
                } else {
                    ForEach(Array(coachOrbs.prefix(3).enumerated()), id: \.element.0) { index, orb in
                        OrbAvatar(colors: orb.1, size: 28)
                            .offset(
                                x: index == 0 ? -8 : (index == 1 ? 8 : 0),
                                y: index == 2 ? 10 : (index == 0 ? -4 : -4)
                            )
                    }
                }
            }
            .frame(width: 44, height: 44)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(allCoachNames)
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.sm) {
                    Text(session.formattedDate)
                    Text("·")
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
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}
