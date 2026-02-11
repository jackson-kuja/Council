import Foundation

enum SessionDeepLinkAction: String {
    case open
    case mute
    case end

    static func from(url: URL) -> SessionDeepLinkAction? {
        guard url.scheme?.lowercased() == "council",
              url.host?.lowercased() == "session" else {
            return nil
        }

        let path = url.pathComponents
            .filter { $0 != "/" }
            .first?
            .lowercased()

        guard let path else { return .open }
        return SessionDeepLinkAction(rawValue: path)
    }
}

extension Notification.Name {
    static let sessionDeepLinkActionRequested = Notification.Name("sessionDeepLinkActionRequested")
}
