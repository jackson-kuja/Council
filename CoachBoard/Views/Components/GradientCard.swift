import SwiftUI

struct GradientCard<Content: View>: View {
    let colors: (Color, Color)
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        colors: (Color, Color),
        cornerRadius: CGFloat = AppSpacing.cardRadius,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(
                LinearGradient(
                    colors: [colors.0.opacity(0.08), colors.1.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
    }
}
