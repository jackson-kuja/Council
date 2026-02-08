import SwiftUI

/// Full transcript view for reviewing a past session
struct TranscriptView: View {
    let session: CoachingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Session info header
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(session.coachName)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))

                    // Transcript messages
                    ForEach(session.transcript) { message in
                        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AppSpacing.xxs) {
                            Text(message.role == .user ? "You" : session.coachName)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textTertiary)

                            Text(message.content)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(AppSpacing.sm)
                                .background(
                                    message.role == .user
                                        ? AppColors.accent.opacity(0.08)
                                        : AppColors.surface
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                        .strokeBorder(AppColors.border, lineWidth: 1)
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
}
