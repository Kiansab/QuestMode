import Foundation
import FirebaseAuth

/// Sends Quest Mode–branded auth emails via the backend (Resend).
/// Falls back to Firebase’s default mail if branded email isn’t production-ready
/// (unverified domain, resend.dev test mode, missing key, cold-start errors, etc.).
enum QuestModeAuthEmail {

    /// Must stay on a Firebase Auth authorized domain (see Firebase Console → Authentication → Settings).
    private static let continueURL = URL(string: "https://questmode-298cc.firebaseapp.com")!

    private static var backendBaseURL: URL? {
        QuestModeRemoteAI.customBackendBaseURL
    }

    private static var actionCodeSettings: ActionCodeSettings {
        let settings = ActionCodeSettings()
        settings.url = continueURL
        settings.handleCodeInApp = false
        return settings
    }

    /// Verification email for the signed-in user.
    /// Prefers branded Resend mail; falls back to Firebase if Resend/domain isn’t ready.
    static func sendVerification(completion: ((Error?) -> Void)? = nil) {
        guard let user = Auth.auth().currentUser else {
            completion?(NSError(domain: "QuestModeAuthEmail", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Not signed in."
            ]))
            return
        }

        Task {
            do {
                try await sendBranded(kind: "verify", email: nil)
                await MainActor.run { completion?(nil) }
            } catch {
                // Branded path not ready / failed → Firebase still delivers to any inbox.
                user.sendEmailVerification(with: actionCodeSettings) { firebaseError in
                    completion?(firebaseError)
                }
            }
        }
    }

    /// Password reset — works while signed out.
    static func sendPasswordReset(email: String, completion: ((Error?) -> Void)? = nil) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        Task {
            do {
                try await sendBranded(kind: "password_reset", email: trimmed, requireAuth: false)
                await MainActor.run { completion?(nil) }
            } catch {
                Auth.auth().sendPasswordReset(withEmail: trimmed, actionCodeSettings: actionCodeSettings) { firebaseError in
                    completion?(firebaseError)
                }
            }
        }
    }

    private static func sendBranded(kind: String, email: String?, requireAuth: Bool = true) async throws {
        guard let base = backendBaseURL else {
            throw URLError(.badURL)
        }
        let url = base.appendingPathComponent("v1").appendingPathComponent("send-auth-email")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Render free tier cold-starts can exceed 20s.
        request.timeoutInterval = 45

        if requireAuth {
            let token = try await idToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: String] = ["kind": kind]
        if let email, !email.isEmpty { body["email"] = email }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 200 {
            return
        }
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            ?? String(data: data, encoding: .utf8)
            ?? "Email send failed"
        throw NSError(domain: "QuestModeAuthEmail", code: http.statusCode, userInfo: [
            NSLocalizedDescriptionKey: message
        ])
    }

    private static func idToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await withCheckedThrowingContinuation { cont in
            user.getIDTokenForcingRefresh(false) { token, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let token, !token.isEmpty {
                    cont.resume(returning: token)
                } else {
                    cont.resume(throwing: URLError(.userAuthenticationRequired))
                }
            }
        }
    }

    private struct ErrorBody: Decodable {
        let error: String?
        let code: String?
    }
}
