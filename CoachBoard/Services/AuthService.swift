import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentNonce: String?

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var userId: String? {
        currentUser?.uid
    }

    // MARK: - Apple Sign In

    /// Prepares a nonce and returns it for use with ASAuthorizationAppleIDRequest.
    /// The raw nonce is stored; the SHA256 hash should be passed to Apple.
    func startSignInWithApple() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let nonce = currentNonce else {
            throw AuthError.missingNonce
        }
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.missingIdentityToken
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        isLoading = true
        error = nil
        defer { isLoading = false }

        try await Auth.auth().signIn(with: firebaseCredential)
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Nonce Helpers

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingNonce
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .missingNonce:
            return "Missing nonce. Please try signing in again."
        case .missingIdentityToken:
            return "Unable to retrieve identity token from Apple."
        }
    }
}
