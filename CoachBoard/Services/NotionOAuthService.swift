import AuthenticationServices
import UIKit

class NotionOAuthService {
    static let shared = NotionOAuthService()

    // TODO: Replace with your Notion OAuth integration client ID
    private let clientId = "2ffd872b-594c-80b2-8681-0037bfebe517"
    private let redirectScheme = "coachboard"
    // Notion requires HTTPS redirect URIs. The Cloud Function bounces to coachboard:// scheme.
    private let redirectURI = "https://us-central1-coachboard-app.cloudfunctions.net/notionOAuthCallback"

    private init() {}

    /// Starts the Notion OAuth flow and returns the access token + workspace info
    @MainActor
    func startOAuthFlow() async throws -> (accessToken: String, workspaceId: String, workspaceName: String) {
        let code = try await requestAuthorizationCode()
        return try await ElevenLabsAPIService.shared.exchangeNotionOAuth(
            code: code,
            redirectUri: redirectURI
        )
    }

    /// Presents the OAuth web view and extracts the authorization code
    @MainActor
    private func requestAuthorizationCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var urlComponents = URLComponents(string: "https://api.notion.com/v1/oauth/authorize")!
            urlComponents.queryItems = [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "owner", value: "user"),
            ]

            let session = ASWebAuthenticationSession(
                url: urlComponents.url!,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: NotionOAuthError.missingCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = PresentationContextProvider.shared
            session.start()
        }
    }
}

enum NotionOAuthError: LocalizedError {
    case missingCode
    case exchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCode: return "No authorization code received from Notion"
        case .exchangeFailed(let msg): return "Failed to exchange Notion code: \(msg)"
        }
    }
}

/// Provides the presentation anchor for ASWebAuthenticationSession
private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
