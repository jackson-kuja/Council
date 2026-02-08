import SwiftUI

struct CoachDetailView: View {
    let coach: Coach
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSession = false
    @StateObject private var profileVM = ProfileViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Orb hero
                OrbAvatar(colors: coach.orbColorPair, size: 200)
                    .frame(height: 220)

                Spacer()
                    .frame(height: 32)

                // Name + description
                VStack(spacing: 10) {
                    Text(coach.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(coach.description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 40)
                }

                Spacer()
                    .frame(height: 12)

                // Opening line
                Text("\"\(coach.firstMessage)\"")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)

                Spacer()

                // Start session
                Button {
                    showSession = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                        Text("Start Session")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(
                        item: coach.shareURL,
                        subject: Text(coach.name),
                        message: Text(coach.shareText)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showSession) {
                SessionView(coach: coach)
            }
            .task {
                await profileVM.loadProfile()
            }
        }
    }
}
