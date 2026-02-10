import SwiftUI

/// Full transcript view for reviewing a past session
struct TranscriptView: View {
    let session: CoachingSession
    @Environment(\.dismiss) private var dismiss

    private var allCoachNames: String {
        let names = [session.coachName] + session.additionalCoachNames
        return names.joined(separator: " + ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Session info header
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(allCoachNames)
                            .font(AppTypography.titleLarge)
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.md) {
                            Label(session.formattedDate, systemImage: "calendar")
                            Label(session.formattedDuration, systemImage: "clock")
                        }
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))

                    // Transcript messages
                    ForEach(session.transcript) { message in
                        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AppSpacing.xxs) {
                            Text(message.role == .user ? "You" : (message.coachName ?? session.coachName))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(
                                    message.role == .user
                                        ? AppColors.textTertiary
                                        : coachColor(for: message.coachId)
                                )

                            Text(message.content)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(AppSpacing.sm)
                                .background(
                                    message.role == .user
                                        ? AppColors.accent.opacity(0.08)
                                        : AppColors.surface
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                        }
                        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
    }

    private func coachColor(for coachId: String?) -> Color {
        guard let coachId else { return AppColors.textTertiary }
        if let coach = Coach.builtInCoaches.first(where: { $0.id == coachId }) {
            return coach.orbColorPair.0
        }
        let index = abs(coachId.hashValue) % AppColors.orbPalettes.count
        return AppColors.orbPalettes[index].0
    }
}
