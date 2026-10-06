import Foundation
import FirebaseAuth

/// Auth emails via **Resend only** (Quest Mode branded). Firebase Auth still owns accounts;
/// Firebase’s built-in mailers are not used for verification or password reset.
enum QuestModeAuthEmail {

    /// Must stay on a Firebase Auth authorized domain (continue URL after tapping the link).
    private static let continueURL = URL(string: "https://questmode-298cc.firebaseapp.com")!

    private static var backendBaseURL: URL? {
        QuestModeRemoteAI.customBackendBaseURL
    }

    /// Verification email for the signed-in user — Resend + Admin-generated link only.
    static func sendVerification(completion: ((Error?) -> Void)? = nil) {
        guard Auth.auth().currentUser != nil else {
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
                await MainActor.run { completion?(friendly(error)) }
            }
        }
    }

    /// Password reset — Resend only (works while signed out).
    static func sendPasswordReset(email: String, completion: ((Error?) -> Void)? = nil) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        Task {
            do {
                try await sendBranded(kind: "password_reset", email: trimmed, requireAuth: false)
                await MainActor.run { completion?(nil) }
            } catch {
                await MainActor.run { completion?(friendly(error)) }
            }
        }
    }

    private static func friendly(_ error: Error) -> Error {
        let ns = error as NSError
        let raw = (ns.localizedDescription).lowercased()
        if raw.contains("resend.dev") || raw.contains("only send testing") || raw.contains("own email") {
            return NSError(domain: "QuestModeAuthEmail", code: ns.code, userInfo: [
                NSLocalizedDescriptionKey:
                    "Branded mail isn’t set up for every inbox yet. Finish questmode.app in Resend (DNS), set RESEND_FROM to noreply@questmode.app on Render, then Resend."
            ])
        }
        if raw.contains("not configured") || raw.contains("missing") || ns.code == 503 {
            return NSError(domain: "QuestModeAuthEmail", code: ns.code, userInfo: [
                NSLocalizedDescriptionKey:
                    "Verification email service isn’t ready. Check Resend + Render (RESEND_API_KEY / RESEND_FROM)."
            ])
        }
        return ns
    }

    private static func sendBranded(kind: String, email: String?, requireAuth: Bool = true) async throws {
        guard let base = backendBaseURL else {
            throw NSError(domain: "QuestModeAuthEmail", code: 503, userInfo: [
                NSLocalizedDescriptionKey: "Quest backend URL missing from this build."
            ])
        }
        let url = base.appendingPathComponent("v1").appendingPathComponent("send-auth-email")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data)
        let message = decoded?.error
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
