import SwiftUI

struct CommunityCoachSheet: View {
    let coach: Coach
    let isOnBoard: Bool
    let onAdd: () -> Void
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                OrbAvatar(colors: coach.orbColorPair, size: 200)
                    .frame(height: 220)

                Spacer()
                    .frame(height: 32)

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

                Text("\"\(coach.firstMessage)\"")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)

                Spacer()

                if isOnBoard {
                    Button {
                        onStart()
                        dismiss()
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
                } else {
                    Button {
                        onAdd()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add to Board")
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
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
    }
}
