import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUserId: String?
    @Published var currentNonce: String?

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
            }
        }
    }

    // MARK: - Apple Sign In

    /// Generates a nonce and returns its SHA256 hash for the Apple Sign In request.
    func startSignInWithApple() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential type."
                return
            }
            guard let nonce = currentNonce else {
                errorMessage = "Missing nonce. Please try again."
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to retrieve identity token."
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            isLoading = true
            errorMessage = nil

            Task {
                do {
                    let authResult = try await Auth.auth().signIn(with: credential)
                    await createUserProfileIfNeeded(
                        user: authResult.user,
                        appleCredential: appleIDCredential
                    )
                    isLoading = false
                } catch {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }

        case .failure(let error):
            // User cancelled or other error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - User Profile Creation

    private func createUserProfileIfNeeded(
        user: User,
        appleCredential: ASAuthorizationAppleIDCredential
    ) async {
        // Build display name from Apple-provided name components
        let displayName: String = {
            if let fullName = appleCredential.fullName {
                let formatter = PersonNameComponentsFormatter()
                let name = formatter.string(from: fullName)
                if !name.isEmpty { return name }
            }
            // Fallback to Firebase display name or default
            return user.displayName ?? "User"
        }()

        let email = appleCredential.email ?? user.email ?? ""

        let profile = UserProfile(
            id: user.uid,
            displayName: displayName,
            email: email,
            photoURL: nil,
            personalContext: .empty,
            createdAt: Date()
        )

        do {
            try await FirebaseService.shared.saveUserProfile(profile)
        } catch {
            // Profile creation failure is non-fatal; user is still signed in
            print("Failed to save user profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nonce Helpers

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

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
