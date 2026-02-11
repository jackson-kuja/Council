import SwiftUI

struct CoachCard: View {
    let coach: Coach
    var isCompact: Bool = false

    var body: some View {
        let (color1, color2) = coach.orbColorPair

        GradientCard(colors: (color1, color2)) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    OrbAvatar(colors: (color1, color2), size: isCompact ? 36 : 44)
                    Spacer()
                    CategoryBadge(category: coach.category)
                }

                Spacer()

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(coach.name)
                        .font(isCompact ? AppTypography.titleSmall : AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(coach.description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: AppSpacing.xs) {
                    ModelBadge(model: coach.llmModel)

                    Spacer()

                    HStack(spacing: 3) {
                        OrbAvatar(colors: (color1, color2), size: 9)
                        Text("\(coach.usageCount)")
                            .font(AppTypography.captionSmall)
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
        }
        .frame(width: isCompact ? AppSpacing.cardWidth : nil)
        .frame(height: AppSpacing.cardHeight)
    }
}
