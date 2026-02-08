import SwiftUI

struct VoiceCard: View {
    let voice: VoiceOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.accent)
                    }
                }

                Text(voice.name)
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.xxs) {
                    if let gender = voice.gender {
                        VoiceLabel(text: gender)
                    }
                    if let accent = voice.accent {
                        VoiceLabel(text: accent)
                    }
                }

                if let desc = voice.descriptive {
                    Text(desc)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(AppSpacing.sm)
            .background(isSelected ? AppColors.accent.opacity(0.08) : AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .strokeBorder(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
    }
}

struct VoiceLabel: View {
    let text: String

    var body: some View {
        Text(text.capitalized)
            .font(AppTypography.captionSmall)
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.surfaceElevated)
            .overlay(
                Capsule()
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}
