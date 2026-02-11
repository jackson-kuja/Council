import SwiftUI

struct CategoryBadge: View {
    let category: CoachCategory

    var body: some View {
        let (color1, _) = category.gradient

        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 10, weight: .semibold))

            Text(category.displayName)
                .font(AppTypography.captionSmall)
                .fontWeight(.medium)
        }
        .foregroundColor(color1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color1.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct ModelBadge: View {
    let model: LLMModel

    var body: some View {
        Text(model.displayName)
            .font(AppTypography.captionSmall)
            .foregroundColor(AppColors.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.surface)
            .overlay(
                Capsule()
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}
