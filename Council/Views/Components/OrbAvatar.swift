import SwiftUI
import ElevenLabsComponents

/// Wraps the real ElevenLabs Metal Orb shader for use outside of live sessions.
/// Shows the authentic orb visuals with a gentle idle animation.
struct OrbAvatar: View {
    let colors: (Color, Color)
    let size: CGFloat

    init(colors: (Color, Color), size: CGFloat = AppSpacing.orbSizeSmall) {
        self.colors = colors
        self.size = size
    }

    var body: some View {
        Orb(
            color1: colors.0,
            color2: colors.1,
            inputVolume: 0,
            outputVolume: 0,
            agentState: .listening
        )
        .frame(width: size, height: size)
    }
}
