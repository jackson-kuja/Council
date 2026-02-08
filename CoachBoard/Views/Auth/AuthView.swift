import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: AppSpacing.xxl) {
                Spacer()

                // Logo / Title
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accent, AppColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("CoachBoard")
                        .font(AppTypography.displayLarge)
                        .foregroundColor(AppColors.textPrimary)

                    Text("AI coaching at your fingertips")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Error
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }

                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    let hashedNonce = authViewModel.startSignInWithApple()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = hashedNonce
                } onCompletion: { result in
                    authViewModel.handleSignInWithApple(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                .padding(.horizontal, AppSpacing.xl)

                Spacer()
                    .frame(height: AppSpacing.huge)
            }
        }
    }
}
