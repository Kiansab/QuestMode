import Foundation
import FirebaseAuth
import FirebaseFunctions

/// Remote AI: (1) your own HTTPS server (`QuestModeQuestBackendURL`), or (2) Firebase Callable, or (3) direct OpenAI on device.
enum QuestModeRemoteAI {

    private static let promptVersion = 1
    private static let callableName = "generateQuestsOpenAI"
    private static let customBackendChatPath = "v1/quest-chat"

    // MARK: - Info.plist

    /// Your public base URL only, e.g. `https://questmode-api.fly.dev` — no trailing slash required.
    static var customBackendBaseURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "QuestModeQuestBackendURL") as? String else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let u = URL(string: t), u.scheme == "https" || u.scheme == "http" else { return nil }
        return u
    }

    static var hasCustomQuestBackendURL: Bool { customBackendBaseURL != nil }

    static var isProxyEnabled: Bool {
        plistBool(forKey: "QuestModeUseFirebaseQuestProxy")
    }

    /// True when either your server URL is set or Firebase proxy is on (signed-in users can skip BYOK).
    static var usesEveryoneServerAI: Bool {
        hasCustomQuestBackendURL || isProxyEnabled
    }

    /// Device/bundle OpenAI key path — **off** by default for production (server key only).
    /// Enable only in Debug Info.plist / local schemes when you intentionally BYOK.
    static var fallbackToDirectOpenAI: Bool {
        if Bundle.main.object(forInfoDictionaryKey: "QuestModeFallbackFromProxyToDirectOpenAI") == nil { return false }
        return plistBool(forKey: "QuestModeFallbackFromProxyToDirectOpenAI")
    }

    private static func plistBool(forKey key: String) -> Bool {
        let v = Bundle.main.object(forInfoDictionaryKey: key)
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        return false
    }

    private static var functionsRegion: String? {
        let s = Bundle.main.object(forInfoDictionaryKey: "QuestModeFirebaseFunctionsRegion") as? String
        return s.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    private static var functions: Functions {
        if let r = functionsRegion {
            return Functions.functions(region: r)
        }
        return Functions.functions()
    }

    // MARK: - Routing

    static func shouldUseCustomBackendHTTP(signedIn: Bool) -> Bool {
        hasCustomQuestBackendURL && signedIn
    }

    static func shouldUseProxyCall(signedIn: Bool) -> Bool {
        isProxyEnabled && signedIn
    }

    // MARK: - Firebase ID token

    private static func firebaseIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AIQuestGeneratorError.openAIResponseDecode("Sign in to Quest Mode to get personalized quests.")
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            user.getIDTokenForcingRefresh(false) { token, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let token = token, !token.isEmpty else {
                    cont.resume(throwing: AIQuestGeneratorError.openAIResponseDecode("Sign in to Quest Mode and try again."))
                    return
                }
                cont.resume(returning: token)
            }
        }
    }

    // MARK: - Custom HTTPS backend

    private struct BackendChatRequest: Encodable {
        let promptVersion: Int
        let kind: String
        let systemPrompt: String
        let userPrompt: String
        let maxTokens: Int?
        let temperature: Double?
    }

    private struct BackendChatResponse: Decodable {
        let assistantContent: String?
        let pong: Bool?
        let error: String?
    }

    static func pingCustomBackend() async throws {
        guard let base = customBackendBaseURL else {
            throw AIQuestGeneratorError.openAIResponseDecode("Personalized quests aren’t available in this build.")
        }
        let url = base.appendingPathComponent(customBackendChatPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Render free tier can cold-start for ~30–60s.
        request.timeoutInterval = 75
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await firebaseIDToken())", forHTTPHeaderField: "Authorization")
        let body = BackendChatRequest(promptVersion: promptVersion, kind: "ping", systemPrompt: "", userPrompt: "", maxTokens: nil, temperature: nil)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIQuestGeneratorError.network(underlying: URLError(.badServerResponse))
        }
        let decoded = try JSONDecoder().decode(BackendChatResponse.self, from: data)
        if http.statusCode != 200 {
            throw AIQuestGeneratorError.httpError(statusCode: http.statusCode, detail: decoded.error ?? String(data: data, encoding: .utf8))
        }
        guard decoded.pong == true else {
            throw AIQuestGeneratorError.openAIResponseDecode("Couldn’t reach the quest service. Try again in a moment.")
        }
    }

    static func fetchCompletionJSONFromCustomBackend(
        systemPrompt: String,
        userPrompt: String,
        kind: String,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) async throws -> String {
        guard let base = customBackendBaseURL else {
            throw AIQuestGeneratorError.openAIResponseDecode("Personalized quests aren’t available in this build.")
        }
        let url = base.appendingPathComponent(customBackendChatPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Render free tier can cold-start for ~30–60s; OpenAI adds a few more.
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await firebaseIDToken())", forHTTPHeaderField: "Authorization")
        let body = BackendChatRequest(
            promptVersion: promptVersion,
            kind: kind,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: maxTokens,
            temperature: temperature
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIQuestGeneratorError.network(underlying: URLError(.badServerResponse))
        }
        let decoded = try JSONDecoder().decode(BackendChatResponse.self, from: data)
        if http.statusCode != 200 {
            throw AIQuestGeneratorError.httpError(statusCode: http.statusCode, detail: decoded.error ?? String(data: data, encoding: .utf8))
        }
        guard let content = decoded.assistantContent?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw AIQuestGeneratorError.openAIResponseDecode(decoded.error ?? "We couldn’t finish creating quests. Try again in a moment.")
        }
        return content
    }

    // MARK: - Firebase Callable

    static func pingFirebaseCallable() async throws {
        let payload: [String: Any] = ["promptVersion": promptVersion, "kind": "ping"]
        let callable = functions.httpsCallable(callableName)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            callable.call(payload) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let data = result?.data as? [String: Any],
                      (data["pong"] as? Bool) == true else {
                    cont.resume(throwing: AIQuestGeneratorError.openAIResponseDecode("Couldn’t reach the quest service. Try again in a moment."))
                    return
                }
                cont.resume()
            }
        }
    }

    static func fetchCompletionJSONFromFirebase(systemPrompt: String, userPrompt: String, kind: String) async throws -> String {
        let payload: [String: Any] = [
            "promptVersion": promptVersion,
            "kind": kind,
            "systemPrompt": systemPrompt,
            "userPrompt": userPrompt
        ]
        let callable = functions.httpsCallable(callableName)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            callable.call(payload) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let data = result?.data as? [String: Any],
                      let content = data["assistantContent"] as? String,
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    cont.resume(throwing: AIQuestGeneratorError.openAIResponseDecode("We couldn’t finish creating quests. Try again in a moment."))
                    return
                }
                cont.resume(returning: content)
            }
        }
    }
}
