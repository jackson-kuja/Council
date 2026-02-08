import SwiftUI

/// Standalone model picker view (reusable)
struct ModelPickerView: View {
    @Binding var selectedModel: LLMModel

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(LLMModel.allCases) { model in
                Button {
                    selectedModel = model
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(AppTypography.titleSmall)
                                .foregroundColor(AppColors.textPrimary)

                            Text(model.subtitle)
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        if selectedModel == model {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(
                        selectedModel == model
                            ? AppColors.accent.opacity(0.06)
                            : AppColors.surface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
            }
        }
    }
}
