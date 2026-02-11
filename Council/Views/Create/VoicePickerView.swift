import SwiftUI
import AVFoundation

@MainActor
class VoicePreviewPlayer: ObservableObject {
    static let shared = VoicePreviewPlayer()
    @Published var playingVoiceId: String?
    private var player: AVPlayer?
    private var observer: Any?

    func toggle(_ voice: VoiceOption) {
        if playingVoiceId == voice.id {
            stop()
            return
        }
        stop()
        guard let urlString = voice.previewUrl, let url = URL(string: urlString) else { return }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        playingVoiceId = voice.id
        player?.play()
    }

    func stop() {
        player?.pause()
        player = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        playingVoiceId = nil
    }
}

struct VoiceCard: View {
    let voice: VoiceOption
    let isSelected: Bool
    let onSelect: () -> Void
    @ObservedObject private var previewPlayer = VoicePreviewPlayer.shared

    private var isPlaying: Bool { previewPlayer.playingVoiceId == voice.id }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Button {
                        previewPlayer.toggle(voice)
                    } label: {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isPlaying ? AppColors.accent : AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)

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
