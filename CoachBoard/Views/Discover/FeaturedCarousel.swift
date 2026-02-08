import SwiftUI

struct FeaturedCarousel: View {
    let coaches: [Coach]
    let onSelect: (Coach) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.md) {
                ForEach(coaches) { coach in
                    FeaturedCard(coach: coach)
                        .onTapGesture { onSelect(coach) }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }
}

struct FeaturedCard: View {
    let coach: Coach

    var body: some View {
        let (color1, color2) = coach.orbColorPair

        GradientCard(colors: (color1, color2)) {
            HStack(spacing: AppSpacing.lg) {
                OrbAvatar(colors: (color1, color2), size: AppSpacing.orbSizeMedium)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    CategoryBadge(category: coach.category)

                    Text(coach.name)
                        .font(AppTypography.displaySmall)
                        .foregroundColor(AppColors.textPrimary)

                    Text(coach.description)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: AppSpacing.sm) {
                        ModelBadge(model: coach.llmModel)

                        HStack(spacing: 3) {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                            Text("\(coach.usageCount) sessions")
                                .font(AppTypography.captionSmall)
                        }
                        .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.lg)
        }
        .frame(width: AppSpacing.featuredCardWidth, height: AppSpacing.featuredCardHeight)
    }
}
