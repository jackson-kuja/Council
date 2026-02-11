import Foundation

enum CoachDeepLinkAction {
    case open(coachId: String)

    /// Parses both URL scheme and universal link formats:
    /// - council://coach/{coachId}
    /// - https://council-coaching.web.app/coach/{coachId}
    static func from(url: URL) -> CoachDeepLinkAction? {
        let scheme = url.scheme?.lowercased() ?? ""

        if scheme == "council" {
            // URL scheme: council://coach/{coachId}
            guard url.host?.lowercased() == "coach" else { return nil }
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard let coachId = pathComponents.first, !coachId.isEmpty else { return nil }
            return .open(coachId: coachId)
        }

        if scheme == "https" || scheme == "http" {
            // Universal link: https://council-coaching.web.app/coach/{coachId}
            let host = url.host?.lowercased() ?? ""
            guard host == "council-coaching.web.app" || host == "coachboard-app.web.app" else { return nil }
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard pathComponents.count >= 2,
                  pathComponents[0] == "coach",
                  !pathComponents[1].isEmpty else { return nil }
            return .open(coachId: pathComponents[1])
        }

        return nil
    }
}

extension Notification.Name {
    static let coachDeepLinkReceived = Notification.Name("coachDeepLinkReceived")
}
