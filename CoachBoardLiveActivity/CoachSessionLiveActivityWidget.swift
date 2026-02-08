import ActivityKit
import WidgetKit
import SwiftUI
import ElevenLabsComponents

private enum SessionWidgetAction: String {
    case open
    case mute
    case end
}

private func sessionActionURL(_ action: SessionWidgetAction) -> URL {
    URL(string: "coachboard://session/\(action.rawValue)")!
}

struct CoachSessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CoachSessionActivityAttributes.self) { context in
            SessionLockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.black)
                .widgetURL(sessionActionURL(.open))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        LiveActivityOrb(
                            primaryColorHex: context.attributes.primaryColorHex,
                            secondaryColorHex: context.attributes.secondaryColorHex,
                            statusLabel: context.state.statusLabel
                        )
                        .frame(width: 24, height: 24)

                        Text(context.attributes.coachName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ConnectionBadge(
                        statusLabel: context.state.statusLabel,
                        isConnected: context.state.isConnected
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        SessionActionIconLink(
                            systemImage: context.state.isMuted ? "mic.fill" : "mic.slash.fill",
                            url: sessionActionURL(.mute)
                        )

                        SessionActionIconLink(
                            systemImage: "xmark.circle.fill",
                            url: sessionActionURL(.end),
                            isDestructive: true
                        )

                        SessionActionIconLink(
                            systemImage: "arrow.up.forward.app.fill",
                            url: sessionActionURL(.open)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                LiveActivityOrb(
                    primaryColorHex: context.attributes.primaryColorHex,
                    secondaryColorHex: context.attributes.secondaryColorHex,
                    statusLabel: context.state.statusLabel
                )
                .frame(width: 20, height: 20)
            } compactTrailing: {
                Image(systemName: context.state.isMuted ? "mic.slash.fill" : "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(context.state.isConnected ? .white : .gray)
            } minimal: {
                LiveActivityOrb(
                    primaryColorHex: context.attributes.primaryColorHex,
                    secondaryColorHex: context.attributes.secondaryColorHex,
                    statusLabel: context.state.statusLabel
                )
                .frame(width: 18, height: 18)
            }
            .keylineTint(.white)
            .widgetURL(sessionActionURL(.open))
        }
    }
}

private struct SessionLockScreenLiveActivityView: View {
    let context: ActivityViewContext<CoachSessionActivityAttributes>

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Text(context.attributes.coachName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer(minLength: 12)

                ConnectionBadge(
                    statusLabel: context.state.statusLabel,
                    isConnected: context.state.isConnected
                )
            }

            LiveActivityOrb(
                primaryColorHex: context.attributes.primaryColorHex,
                secondaryColorHex: context.attributes.secondaryColorHex,
                statusLabel: context.state.statusLabel
            )
            .frame(width: 112, height: 112)

            HStack(spacing: 8) {
                SessionActionLink(
                    title: context.state.isMuted ? "Unmute" : "Mute",
                    systemImage: context.state.isMuted ? "mic.fill" : "mic.slash.fill",
                    url: sessionActionURL(.mute)
                )
                SessionActionLink(
                    title: "End",
                    systemImage: "xmark",
                    url: sessionActionURL(.end),
                    isDestructive: true
                )
                SessionActionLink(
                    title: "Open",
                    systemImage: "arrow.up.forward",
                    url: sessionActionURL(.open)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 2)
    }
}

private struct LiveActivityOrb: View {
    let primaryColorHex: String
    let secondaryColorHex: String
    let statusLabel: String

    private var visualizerState: VisualizerAgentState {
        switch statusLabel.lowercased() {
        case "speaking":
            return .speaking
        case "thinking":
            return .thinking
        case "listening":
            return .listening
        default:
            return .unknown
        }
    }

    private var inputVolume: Float {
        switch visualizerState {
        case .listening:
            return 0.35
        case .thinking:
            return 0.22
        case .speaking:
            return 0.12
        default:
            return 0.16
        }
    }

    private var outputVolume: Float {
        switch visualizerState {
        case .speaking:
            return 0.45
        case .thinking:
            return 0.18
        case .listening:
            return 0.1
        default:
            return 0.14
        }
    }

    var body: some View {
        Orb(
            color1: Color(hex: primaryColorHex),
            color2: Color(hex: secondaryColorHex),
            inputVolume: inputVolume,
            outputVolume: outputVolume,
            agentState: visualizerState
        )
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct ConnectionBadge: View {
    let statusLabel: String
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)

            Text(statusLabel)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.06))
        )
    }
}

private struct SessionActionLink: View {
    let title: String
    let systemImage: String
    let url: URL
    var isDestructive: Bool = false

    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isDestructive ? Color.red : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isDestructive ? Color.red.opacity(0.1) : Color.black.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SessionActionIconLink: View {
    let systemImage: String
    let url: URL
    var isDestructive: Bool = false

    var body: some View {
        Link(destination: url) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDestructive ? Color.red : Color.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isDestructive ? Color.red.opacity(0.2) : Color.white.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch sanitized.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
