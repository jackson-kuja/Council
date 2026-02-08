import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<CoachSessionActivityAttributes>?

    private init() {}

    private var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(
        sessionId: String,
        coachName: String,
        primaryColorHex: String,
        secondaryColorHex: String,
        statusLabel: String,
        isMuted: Bool,
        isConnected: Bool,
        startedAt: Date,
        elapsedSeconds: Int
    ) async {
        guard activitiesEnabled else { return }

        if let activity = resolveActivity(sessionId: sessionId) {
            currentActivity = activity
            await update(
                sessionId: sessionId,
                statusLabel: statusLabel,
                isMuted: isMuted,
                isConnected: isConnected,
                startedAt: startedAt,
                elapsedSeconds: elapsedSeconds
            )
            return
        }

        let attributes = CoachSessionActivityAttributes(
            sessionId: sessionId,
            coachName: coachName,
            primaryColorHex: primaryColorHex,
            secondaryColorHex: secondaryColorHex
        )
        let content = ActivityContent(
            state: CoachSessionActivityAttributes.ContentState(
                statusLabel: statusLabel,
                isMuted: isMuted,
                isConnected: isConnected,
                startedAt: startedAt,
                elapsedSeconds: elapsedSeconds
            ),
            staleDate: nil
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {}
    }

    func update(
        sessionId: String,
        statusLabel: String,
        isMuted: Bool,
        isConnected: Bool,
        startedAt: Date,
        elapsedSeconds: Int
    ) async {
        guard activitiesEnabled else { return }
        guard let activity = resolveActivity(sessionId: sessionId) else { return }
        currentActivity = activity

        let content = ActivityContent(
            state: CoachSessionActivityAttributes.ContentState(
                statusLabel: statusLabel,
                isMuted: isMuted,
                isConnected: isConnected,
                startedAt: startedAt,
                elapsedSeconds: elapsedSeconds
            ),
            staleDate: nil
        )

        await activity.update(content)
    }

    func end(
        sessionId: String,
        statusLabel: String,
        isMuted: Bool,
        isConnected: Bool,
        startedAt: Date,
        elapsedSeconds: Int
    ) async {
        guard let activity = resolveActivity(sessionId: sessionId) else { return }

        let finalContent = ActivityContent(
            state: CoachSessionActivityAttributes.ContentState(
                statusLabel: statusLabel,
                isMuted: isMuted,
                isConnected: isConnected,
                startedAt: startedAt,
                elapsedSeconds: elapsedSeconds
            ),
            staleDate: Date()
        )

        await activity.end(finalContent, dismissalPolicy: .immediate)
        if currentActivity?.id == activity.id {
            currentActivity = nil
        }
    }

    private func resolveActivity(sessionId: String) -> Activity<CoachSessionActivityAttributes>? {
        if let currentActivity, currentActivity.attributes.sessionId == sessionId {
            return currentActivity
        }

        return Activity<CoachSessionActivityAttributes>.activities.first {
            $0.attributes.sessionId == sessionId
        }
    }
}
