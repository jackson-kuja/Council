import ActivityKit
import WidgetKit
import SwiftUI

private enum SessionWidgetAction: String {
    case open
    case mute
    case end
}

private func sessionActionURL(_ action: SessionWidgetAction) -> URL {
    URL(string: "council://session/\(action.rawValue)")!
}

struct CoachSessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CoachSessionActivityAttributes.self) { context in
            SessionLockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(sessionActionURL(.open))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        LiveActivityOrb(
                            primaryColorHex: context.attributes.primaryColorHex,
                            secondaryColorHex: context.attributes.secondaryColorHex
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
                    secondaryColorHex: context.attributes.secondaryColorHex
                )
                .frame(width: 20, height: 20)
            } compactTrailing: {
                Image(systemName: context.state.isMuted ? "mic.slash.fill" : "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(context.state.isConnected ? .white : .gray)
            } minimal: {
                LiveActivityOrb(
                    primaryColorHex: context.attributes.primaryColorHex,
                    secondaryColorHex: context.attributes.secondaryColorHex
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
        HStack(spacing: 14) {
            LiveActivityOrb(
                primaryColorHex: context.attributes.primaryColorHex,
                secondaryColorHex: context.attributes.secondaryColorHex
            )
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(context.attributes.coachName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    ConnectionBadge(
                        statusLabel: context.state.statusLabel,
                        isConnected: context.state.isConnected
                    )
                }

                HStack(spacing: 6) {
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
        }
        .padding(16)
    }
}

private struct LiveActivityOrb: View {
    let primaryColorHex: String
    let secondaryColorHex: String

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: primaryColorHex), Color(hex: secondaryColorHex)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct ConnectionBadge: View {
    let statusLabel: String
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 5, height: 5)

            Text(statusLabel)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.15))
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isDestructive ? Color.red : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(isDestructive ? Color.red.opacity(0.25) : Color.white.opacity(0.15))
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
