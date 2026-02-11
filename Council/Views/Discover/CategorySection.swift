import SwiftUI

struct CategorySection: View {
    let category: CoachCategory
    let coaches: [Coach]
    let onSelect: (Coach) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Section Header
            HStack {
                let (color1, _) = category.gradient
                Image(systemName: category.icon)
                    .foregroundColor(color1)

                Text(category.displayName)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text("\(coaches.count) coaches")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.lg)

            // Horizontal scroll of cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(coaches) { coach in
                        CoachCard(coach: coach, isCompact: true)
                            .onTapGesture { onSelect(coach) }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }
}
