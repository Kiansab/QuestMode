import Foundation
import FirebaseAuth

enum AIQuestGeneratorError: LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int, detail: String?)
    case network(underlying: Error)
    case openAIResponseDecode(String)
    case emptyChoices
    case invalidJSON
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key found. In Profile, paste your OpenAI secret key (or use OpenAISecrets.plist / Xcode scheme for development)."
        case .httpError(let code, let detail):
            if let detail, !detail.isEmpty { return detail }
            return Self.fallbackMessageForHTTPStatus(code)
        case .network(let underlying):
            return "Network: \(underlying.localizedDescription)"
        case .openAIResponseDecode(let msg):
            return msg
        case .emptyChoices:
            return "OpenAI returned no message content. Try again."
        case .invalidJSON:
            return "Couldn’t read the model’s JSON."
        case .validationFailed:
            return "Generated quests didn’t validate. Tap Refresh to try again."
        }
    }

    private static func fallbackMessageForHTTPStatus(_ code: Int) -> String {
        switch code {
        case 401:
            return "OpenAI returned HTTP 401 with no error details. Usually: wrong or revoked API key, or a bad OpenAI-Organization / OpenAI-Project header. Use a secret key from platform.openai.com/api-keys in OpenAISecrets.plist; remove optional org/project lines if unsure."
        case 403:
            return "OpenAI returned HTTP 403 (forbidden). Check project permissions, organization access, or regional restrictions."
        case 429:
            return "OpenAI returned HTTP 429 (rate limited). Wait and try again."
        case 500...599:
            return "OpenAI server error (HTTP \(code)). Try again later."
        default:
            return "OpenAI returned HTTP \(code). Check platform.openai.com status, billing, and API key."
        }
    }
}

/// Calls OpenAI to create personalized daily quests from the onboarding profile.
///
/// Key resolution order: Keychain (saved in Profile) → `OpenAISecrets.plist` → `OPENAI_API_KEY` env → `OPENAI_API_KEY` in Info.plist.
/// Optional in the same plist (or env): `OPENAI_ORGANIZATION_ID`, `OPENAI_PROJECT_ID` — sent as
/// `OpenAI-Organization` / `OpenAI-Project` when set. OpenAI requires these for some accounts
/// (multiple orgs or legacy user keys); see platform.openai.com docs → Authentication.
enum AIQuestGenerator {

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let model = "gpt-4o-mini"

    private struct OpenAIAuthContext {
        let apiKey: String
        let organizationId: String?
        let projectId: String?
    }

    /// Removes spaces, zero-width, and BOM that often sneak in when pasting keys.
    private static func sanitizeSecretString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for bad in ["\u{FEFF}", "\u{200B}", "\u{200C}", "\u{200D}", "\u{00A0}"] {
            s = s.replacingOccurrences(of: bad, with: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripSurroundingQuotes(_ s: String) -> String {
        var t = s
        let pairs: [(Character, Character)] = [
            ("\"", "\""), ("'", "'"),
            ("\u{201C}", "\u{201D}"), ("\u{2018}", "\u{2019}")
        ]
        for (a, b) in pairs {
            if t.count >= 2, t.first == a, t.last == b {
                t.removeFirst()
                t.removeLast()
            }
        }
        return String(t)
    }

    /// OpenAI secret keys are ASCII; strips stray Unicode, quotes, and common paste mistakes that break auth.
    private static func normalizeOpenAIAPIKey(_ raw: String) -> String {
        var cleaned = sanitizeSecretString(raw)
        cleaned = stripSurroundingQuotes(cleaned)
        // Keys never contain `"`; users often paste `""` or `"sk-…"` inside plist <string>.
        cleaned = cleaned.replacingOccurrences(of: "\"", with: "")
        if cleaned.lowercased().hasPrefix("bearer ") {
            cleaned = String(cleaned.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        return String(cleaned.unicodeScalars.filter { (33...126).contains($0.value) })
    }

    /// Validates and normalizes a user-pasted key for saving to Keychain.
    static func normalizedSecretKeyIfValid(_ raw: String) -> String? {
        let n = normalizeOpenAIAPIKey(raw)
        guard !n.isEmpty, n.hasPrefix("sk-") else { return nil }
        return n
    }

    /// Where the raw string came from (before normalization). Used for diagnostics only.
    private static func resolveRawKeyAndSource() -> (raw: String?, source: String) {
        if let raw = OpenAIAPIKeyStore.loadRaw() {
            let t = sanitizeSecretString(raw)
            if !t.isEmpty { return (raw, "Keychain (saved in Profile)") }
        }
        if let plist = loadSecretsPlist(),
           let raw = plist["OPENAI_API_KEY"] as? String {
            let t = sanitizeSecretString(raw)
            if !t.isEmpty { return (raw, "OpenAISecrets.plist") }
        }
        if let raw = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            let t = sanitizeSecretString(raw)
            if !t.isEmpty { return (raw, "Xcode scheme env: OPENAI_API_KEY") }
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            let t = sanitizeSecretString(raw)
            if !t.isEmpty { return (raw, "Info.plist OPENAI_API_KEY") }
        }
        return (nil, "none")
    }

    private static func loadSecretsPlist() -> [String: Any]? {
        var urls: [URL] = []
        if let u = Bundle.main.url(forResource: "OpenAISecrets", withExtension: "plist") {
            urls.append(u)
        }
        if let extra = Bundle.main.urls(forResourcesWithExtension: "plist", subdirectory: nil) {
            urls.append(contentsOf: extra.filter { $0.lastPathComponent == "OpenAISecrets.plist" })
        }
        var seen = Set<String>()
        for url in urls {
            guard seen.insert(url.path).inserted else { continue }
            if let dict = NSDictionary(contentsOf: url) as? [String: Any] { return dict }
        }
        return nil
    }

    private static func stringFromEnv(_ key: String) -> String? {
        guard let raw = ProcessInfo.processInfo.environment[key] else { return nil }
        let t = sanitizeSecretString(raw)
        return t.isEmpty ? nil : t
    }

    private static func resolvedAuthContext() -> OpenAIAuthContext? {
        let plist = loadSecretsPlist()
        func fromPlist(_ key: String) -> String? {
            guard let raw = plist?[key] as? String else { return nil }
            let t = sanitizeSecretString(raw)
            return t.isEmpty ? nil : t
        }
        guard let rawKey = resolveRawKeyAndSource().raw else { return nil }
        let normalizedKey = normalizeOpenAIAPIKey(rawKey)
        guard !normalizedKey.isEmpty, normalizedKey.hasPrefix("sk-") else { return nil }
        let organizationId = fromPlist("OPENAI_ORGANIZATION_ID") ?? stringFromEnv("OPENAI_ORGANIZATION_ID")
        let projectId = fromPlist("OPENAI_PROJECT_ID") ?? stringFromEnv("OPENAI_PROJECT_ID")
        return OpenAIAuthContext(apiKey: normalizedKey, organizationId: organizationId, projectId: projectId)
    }

    static func resolvedAPIKey() -> String? {
        resolvedAuthContext()?.apiKey
    }

    /// Non-secret details: where the key was loaded from, length, sk- prefix check, last 4 chars, which headers are sent.
    /// Use this to verify paste issues (quotes, wrong file, env override) without exposing the full key.
    static func openAIKeyDiagnosticsSummary() -> String {
        let (rawOpt, src) = resolveRawKeyAndSource()
        guard let raw = rawOpt else {
            let bundleHint: String
            if Bundle.main.url(forResource: "OpenAISecrets", withExtension: "plist") == nil {
                bundleHint = "\n\nOpenAISecrets.plist is missing from the app bundle. If that file was listed in .gitignore, Xcode’s synchronized folder may skip it—remove the ignore, clean build, and run again."
            } else {
                bundleHint = "\n\nThe plist is in the bundle but OPENAI_API_KEY is empty or unreadable—paste your sk-… key as the string value."
            }
            let proxyHint: String
            if QuestModeRemoteAI.hasCustomQuestBackendURL {
                proxyHint = "\n\nQuestModeQuestBackendURL is set: signed-in users can use your server without a local key."
            } else if QuestModeRemoteAI.isProxyEnabled {
                proxyHint = "\n\nQuestModeUseFirebaseQuestProxy is enabled: signed-in users can use Firebase Functions without a local key once deployed."
            } else {
                proxyHint = ""
            }
            return "No key loaded. Add your key in Profile (saved to Keychain), or OPENAI_API_KEY in OpenAISecrets.plist, or the Run scheme’s environment variables.\(bundleHint)\(proxyHint)"
        }
        let key = normalizeOpenAIAPIKey(raw)
        guard !key.isEmpty else {
            return "Key text was found (\(src)) but became empty after cleanup — remove quotes/spaces around the key or paste again."
        }
        guard key.hasPrefix("sk-") else {
            return "Key from \(src) does not start with sk- after cleanup. OpenAI secret keys must begin with sk-."
        }

        let plist = loadSecretsPlist()
        func fromPlist(_ k: String) -> String? {
            guard let raw = plist?[k] as? String else { return nil }
            let t = sanitizeSecretString(raw)
            return t.isEmpty ? nil : t
        }
        let org = fromPlist("OPENAI_ORGANIZATION_ID") ?? stringFromEnv("OPENAI_ORGANIZATION_ID")
        let proj = fromPlist("OPENAI_PROJECT_ID") ?? stringFromEnv("OPENAI_PROJECT_ID")
        let orgSent = org.map { !$0.isEmpty && $0.hasPrefix("org-") } ?? false
        let projSent = proj.map { !$0.isEmpty && $0.hasPrefix("proj_") } ?? false

        var lines: [String] = []
        lines.append("Loaded from: \(src)")
        if src == "Xcode scheme env: OPENAI_API_KEY" {
            lines.append("Note: scheme env overrides plist (not Keychain). Remove OPENAI_API_KEY from the scheme if you want the plist or Profile key to apply.")
        }
        lines.append("Key length: \(key.count) characters (project keys are often ~150+)")
        lines.append("Starts with: \(String(key.prefix(7)))…")
        if key.count >= 4 {
            lines.append("Ends with: …\(key.suffix(4)) — match this to the last 4 in the dashboard if shown")
        }
        lines.append("OpenAI-Organization sent: \(orgSent ? "yes (\(String(org!.prefix(10)))…)" : "no")")
        lines.append("OpenAI-Project sent: \(projSent ? "yes (\(String(proj!.prefix(10)))…)" : "no")")
        lines.append("If auth still fails: create a new key at platform.openai.com/api-keys, paste only the key (no Bearer, no quotes), delete optional org/project rows unless sure, clean build.")
        return lines.joined(separator: "\n")
    }

    /// GET `/v1/models` for device keys, or ping your HTTPS backend / Firebase Callable when the key lives on the server.
    static func verifyOpenAIAPICredentials() async throws {
        let signedIn = Auth.auth().currentUser != nil
        if QuestModeRemoteAI.shouldUseCustomBackendHTTP(signedIn: signedIn), resolvedAuthContext() == nil {
            try await QuestModeRemoteAI.pingCustomBackend()
            return
        }
        if QuestModeRemoteAI.shouldUseProxyCall(signedIn: signedIn), resolvedAuthContext() == nil {
            try await QuestModeRemoteAI.pingFirebaseCallable()
            return
        }
        guard let auth = resolvedAuthContext() else { throw AIQuestGeneratorError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        applyOpenAIAuthHeaders(to: &request, auth: auth)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIQuestGeneratorError.network(underlying: error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AIQuestGeneratorError.httpError(statusCode: -1, detail: "Not an HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let detail = parseOpenAIErrorBody(
                data,
                httpStatusCode: http.statusCode,
                requestId: http.value(forHTTPHeaderField: "x-request-id")
            )
            throw AIQuestGeneratorError.httpError(statusCode: http.statusCode, detail: detail)
        }
    }

    // MARK: - Public

    /// Generates exactly three quests for today.
    static func generateDailyQuests(
        profile: OnboardingProfile,
        username: String,
        calendarDayKey: String,
        excludedTitles: [String],
        allowedCategories: [String]
    ) async throws -> [Quest] {
        let userPrompt = buildDailyPrompt(
            profile: profile,
            username: username,
            calendarDayKey: calendarDayKey,
            excludedTitles: excludedTitles,
            allowedCategories: allowedCategories
        )
        let json = try await completeChatJSON(
            system: dailySystemPrompt,
            user: userPrompt,
            kind: "daily"
        )
        let decoded = try parseQuestPayload(json)
        let normalizedExcluded = Set(excludedTitles.map { normalizeTitle($0) })
        guard let valid = validateQuests(decoded, allowedCategories: allowedCategories, excludedNormalized: normalizedExcluded, expectedCount: 3) else {
            throw AIQuestGeneratorError.validationFailed
        }
        return valid
    }

    /// One replacement quest (e.g. swap); must differ from `excludedTitles`.
    static func generateReplacementQuest(
        profile: OnboardingProfile,
        username: String,
        calendarDayKey: String,
        excludedTitles: [String],
        allowedCategories: [String]
    ) async throws -> Quest {
        let userPrompt = buildReplacementPrompt(
            profile: profile,
            username: username,
            calendarDayKey: calendarDayKey,
            excludedTitles: excludedTitles,
            allowedCategories: allowedCategories
        )
        let json = try await completeChatJSON(
            system: replacementSystemPrompt,
            user: userPrompt,
            kind: "replacement"
        )
        let decoded = try parseQuestPayload(json)
        let normalizedExcluded = Set(excludedTitles.map { normalizeTitle($0) })
        guard let one = validateQuests(decoded, allowedCategories: allowedCategories, excludedNormalized: normalizedExcluded, expectedCount: 1)?.first else {
            throw AIQuestGeneratorError.validationFailed
        }
        return one
    }

    // MARK: - Prompts

    private static let dailySystemPrompt = """
    You are Quest Mode’s quest designer. Output only valid JSON (no markdown).
    Create exactly 3 daily quests: real-life, safe, legal, ethical, completable today without purchases.
    No medical diagnosis or treatment claims. Keep titles concrete and varied (different verbs, contexts, and objects).
    Each quest must use a distinct approach so titles are not similar to each other.
    When the user provided a “personal goal” or free-text note in the questionnaire, that text is the highest priority: shape every quest so it clearly connects to what they said they are working toward, in addition to their focus, time budget, and obstacles.
    """

    private static let replacementSystemPrompt = """
    You are Quest Mode’s quest designer. Output only valid JSON (no markdown).
    Create exactly 1 daily quest: real-life, safe, legal, ethical, completable today without purchases.
    No medical claims. If a personal goal note is provided, the quest must directly support that goal while fitting focus, time, and obstacles.
    """

    private static func buildDailyPrompt(
        profile: OnboardingProfile,
        username: String,
        calendarDayKey: String,
        excludedTitles: [String],
        allowedCategories: [String]
    ) -> String {
        let obstacles = profile.obstacles.map(\.title).joined(separator: "; ")
        let excludedBlock = excludedTitles.isEmpty
            ? "(none yet)"
            : excludedTitles.prefix(80).joined(separator: " | ")
        let note = profile.personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeNote = note.replacingOccurrences(of: "\"", with: "'")
        let noteSection: String
        if note.isEmpty {
            noteSection = """
            Questionnaire — what they said they’re working on (no free-text goal was given; rely on focus, time, obstacles below):
            """
        } else {
            noteSection = """
            PRIMARY — what they said they’re working toward (treat this as the main creative brief; every quest should clearly connect to this in plain, practical language):
            “\(safeNote)”
            """
        }
        return """
        Player name: \(username)
        Calendar day id: \(calendarDayKey) (light variety only).

        \(noteSection)

        Questionnaire — primary focus: \(profile.primaryFocus.title) — \(profile.primaryFocus.subtitle)
        Time budget: \(profile.timeBudget.title) — \(profile.timeBudget.detail)
        Obstacles: \(obstacles.isEmpty ? "none selected" : obstacles)

        Allowed categories (use each string exactly): \(allowedCategories.joined(separator: ", "))

        Past quest titles to NEVER repeat or closely paraphrase:
        \(excludedBlock)

        Return JSON with this shape exactly:
        {"quests":[{"category":"Adventure","title":"...","difficulty":"Easy","xp":45,"time":"10 min"}]}
        Rules:
        - Exactly 3 objects in "quests".
        - If a PRIMARY goal was given above, at least one quest title must explicitly reflect that goal; all three should support it together with focus, time, and obstacles.
        - If no PRIMARY goal was given, still align all three with focus, time, and obstacles.
        - "category" must be one of the allowed categories exactly.
        - "difficulty" is "Easy", "Medium", or "Hard".
        - "xp" integer 25 to 90.
        - "time" a short label like "5 min", "12 min", "25 min" matching the time budget.
        - Titles must be mutually distinct and unlike any excluded title.
        """
    }

    private static func buildReplacementPrompt(
        profile: OnboardingProfile,
        username: String,
        calendarDayKey: String,
        excludedTitles: [String],
        allowedCategories: [String]
    ) -> String {
        let obstacles = profile.obstacles.map(\.title).joined(separator: "; ")
        let excludedBlock = excludedTitles.prefix(80).joined(separator: " | ")
        let note = profile.personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeNote = note.replacingOccurrences(of: "\"", with: "'")
        let noteLine = note.isEmpty
            ? "(No free-text goal — use focus, time, obstacles.)"
            : "PRIMARY goal they stated: “\(safeNote)” — this replacement must support that goal."
        return """
        Player name: \(username)
        Calendar day id: \(calendarDayKey)

        \(noteLine)
        Focus: \(profile.primaryFocus.title). Time: \(profile.timeBudget.title). Obstacles: \(obstacles.isEmpty ? "none" : obstacles)

        Allowed categories: \(allowedCategories.joined(separator: ", "))

        Titles to avoid (do not repeat or mimic):
        \(excludedBlock)

        Return JSON: {"quests":[{"category":"Health","title":"...","difficulty":"Easy","xp":40,"time":"8 min"}]}
        Exactly 1 quest. category must match allowed list exactly.
        """
    }

    // MARK: - Networking

    private struct ChatRequest: Encodable {
        let model: String
        let temperature: Double
        let messages: [Msg]
        let response_format: ResponseFormat
        struct Msg: Encodable { let role: String; let content: String }
        struct ResponseFormat: Encodable { let type: String }
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable { let message: Msg }
        struct Msg: Decodable { let content: String }
    }

    /// Order: your HTTPS backend → Firebase Callable → direct OpenAI (device/bundle key).
    private static func completeChatJSON(system: String, user: String, kind: String) async throws -> String {
        let signedIn = Auth.auth().currentUser != nil

        if QuestModeRemoteAI.shouldUseCustomBackendHTTP(signedIn: signedIn) {
            do {
                return try await QuestModeRemoteAI.fetchCompletionJSONFromCustomBackend(
                    systemPrompt: system,
                    userPrompt: user,
                    kind: kind
                )
            } catch {
                if QuestModeRemoteAI.fallbackToDirectOpenAI, let auth = resolvedAuthContext() {
                    return try await requestCompletionJSON(system: system, user: user, auth: auth)
                }
                throw error
            }
        }

        if QuestModeRemoteAI.shouldUseProxyCall(signedIn: signedIn) {
            do {
                return try await QuestModeRemoteAI.fetchCompletionJSONFromFirebase(
                    systemPrompt: system,
                    userPrompt: user,
                    kind: kind
                )
            } catch {
                if QuestModeRemoteAI.fallbackToDirectOpenAI, let auth = resolvedAuthContext() {
                    return try await requestCompletionJSON(system: system, user: user, auth: auth)
                }
                throw error
            }
        }

        guard let auth = resolvedAuthContext() else { throw AIQuestGeneratorError.missingAPIKey }
        return try await requestCompletionJSON(system: system, user: user, auth: auth)
    }

    /// Sends `OpenAI-Organization` only when the value looks like a real org id (`org-…`). Wrong values often yield 401.
    private static func applyOpenAIAuthHeaders(to request: inout URLRequest, auth: OpenAIAuthContext) {
        request.setValue("Bearer \(auth.apiKey)", forHTTPHeaderField: "Authorization")
        if let org = auth.organizationId, !org.isEmpty, org.hasPrefix("org-") {
            request.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }
        // Wrong `OpenAI-Project` values often produce 401 "incorrect API key". Only send dashboard-style ids (`proj_…`).
        if let proj = auth.projectId, !proj.isEmpty, proj.hasPrefix("proj_") {
            request.setValue(proj, forHTTPHeaderField: "OpenAI-Project")
        }
    }

    private static func requestCompletionJSON(system: String, user: String, auth: OpenAIAuthContext) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyOpenAIAuthHeaders(to: &request, auth: auth)

        let body = ChatRequest(
            model: model,
            temperature: 0.85,
            messages: [
                ChatRequest.Msg(role: "system", content: system),
                ChatRequest.Msg(role: "user", content: user)
            ],
            response_format: ChatRequest.ResponseFormat(type: "json_object")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIQuestGeneratorError.network(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIQuestGeneratorError.httpError(statusCode: -1, detail: "Not an HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let detail = parseOpenAIErrorBody(
                data,
                httpStatusCode: http.statusCode,
                requestId: http.value(forHTTPHeaderField: "x-request-id")
            )
            throw AIQuestGeneratorError.httpError(statusCode: http.statusCode, detail: detail)
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
                throw AIQuestGeneratorError.emptyChoices
            }
            return content
        } catch {
            if let q = error as? AIQuestGeneratorError { throw q }
            let snippet = String(data: Data(data.prefix(400)), encoding: .utf8) ?? ""
            throw AIQuestGeneratorError.openAIResponseDecode(
                "Couldn’t parse OpenAI JSON (\(error.localizedDescription)). Start of response: \(snippet.prefix(180))"
            )
        }
    }

    /// Builds a precise, multi-line explanation from OpenAI’s JSON error body and HTTP status.
    private static func parseOpenAIErrorBody(_ data: Data, httpStatusCode: Int, requestId: String?) -> String? {
        struct OpenAIErr: Decodable {
            struct Inner: Decodable {
                let message: String?
                let type: String?
                /// e.g. `invalid_api_key`, `insufficient_quota`
                let code: String?
                let param: String?
            }
            let error: Inner?
        }

        var lines: [String] = []
        lines.append("HTTP \(httpStatusCode) from OpenAI.")

        if let o = try? JSONDecoder().decode(OpenAIErr.self, from: data), let e = o.error {
            if let m = e.message, !m.isEmpty {
                lines.append("Message: \(m)")
            }
            if let c = e.code, !c.isEmpty {
                lines.append("Error code: \(c)")
                let hint = hintForOpenAIErrorCode(c, type: e.type, message: e.message)
                if !hint.isEmpty { lines.append("Likely cause: \(hint)") }
            } else if let t = e.type, !t.isEmpty {
                lines.append("Error type: \(t)")
                let hint = hintForOpenAIErrorType(t, message: e.message)
                if !hint.isEmpty { lines.append("Likely cause: \(hint)") }
            }
            if let p = e.param, !p.isEmpty {
                lines.append("Parameter: \(p)")
            }
        } else if let raw = String(data: data, encoding: .utf8), !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Raw response: \(String(raw.prefix(400)))")
            lines.append("Likely cause: \(hintForHTTPStatusAlone(httpStatusCode))")
        } else {
            lines.append("Empty body.")
            lines.append("Likely cause: \(hintForHTTPStatusAlone(httpStatusCode))")
        }

        if let rid = requestId, !rid.isEmpty {
            lines.append("Request ID (for support): \(rid)")
        }

        return lines.joined(separator: "\n")
    }

    private static func hintForHTTPStatusAlone(_ code: Int) -> String {
        switch code {
        case 401:
            return "Authentication failed. Use a current secret API key from platform.openai.com/api-keys (not your ChatGPT password). If OPENAI_ORGANIZATION_ID or OPENAI_PROJECT_ID is set in OpenAISecrets.plist, they must match the org/project for that key, or remove those keys."
        case 403:
            return "Access denied for this key or organization."
        case 429:
            return "Too many requests; wait and retry."
        default:
            return "See OpenAI’s error code docs and your dashboard (billing, API keys)."
        }
    }

    private static func hintForOpenAIErrorType(_ type: String, message: String?) -> String {
        switch type {
        case "invalid_request_error":
            if message?.localizedCaseInsensitiveContains("api key") == true { return hintForOpenAIErrorCode("invalid_api_key", type: type, message: message) }
            return "The request format or parameters were rejected. Check the Message line above."
        case "authentication_error":
            return "Authentication failed. Confirm the API key and any org/project headers."
        case "permission_error":
            return "This key is not allowed to perform this action for the chosen model or project."
        case "rate_limit_error":
            return "Rate limit; retry after a short wait or upgrade limits."
        case "insufficient_quota":
            return "Billing or quota: add payment method or credits at platform.openai.com."
        default:
            return ""
        }
    }

    private static func hintForOpenAIErrorCode(_ code: String, type: String?, message: String?) -> String {
        switch code {
        case "invalid_api_key":
            return "The secret key is wrong, revoked, expired, or for a different project than your org/project headers. Create a new key at platform.openai.com/api-keys and put it in OPENAI_API_KEY in OpenAISecrets.plist only. Remove OPENAI_ORGANIZATION_ID / OPENAI_PROJECT_ID unless they are exactly correct (org-… and proj_…)."
        case "insufficient_quota":
            return "No quota or billing issue: open platform.openai.com → Billing and ensure the API can be charged."
        case "billing_hard_limit_reached":
            return "Monthly budget or hard limit hit; raise the limit or add credits in Billing."
        case "rate_limit_exceeded":
            return "Too many requests; wait briefly and try again."
        case "model_not_found":
            return "The model name isn’t available to this key or was renamed; the app uses gpt-4o-mini."
        case "context_length_exceeded":
            return "Prompt too long for the model (unlikely from this app)."
        case "invalid_organization":
            return "OpenAI-Organization header doesn’t match a valid org for this key."
        case "account_deactivated":
            return "The account or key is revoked or deactivated."
        default:
            if code.hasPrefix("invalid") { return "Invalid request; read the Message line and OpenAI docs for code \(code)." }
            return ""
        }
    }

    /// Maps any thrown error to a user-readable string (for Profile / debugging).
    static func friendlyMessage(for error: Error) -> String {
        if let q = error as? AIQuestGeneratorError {
            return q.errorDescription ?? "Quest generation failed."
        }
        return error.localizedDescription
    }

    // MARK: - Parse & validate

    private struct QuestPayload: Decodable {
        let quests: [QuestDTO]
    }

    private struct QuestDTO: Decodable {
        let category: String
        let title: String
        let difficulty: String
        let xp: Int
        let time: String
    }

    private static func parseQuestPayload(_ json: String) throws -> [Quest] {
        guard let data = json.data(using: .utf8) else { throw AIQuestGeneratorError.invalidJSON }
        let payload = try JSONDecoder().decode(QuestPayload.self, from: data)
        return payload.quests.map {
            Quest(
                category: $0.category,
                title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                difficulty: $0.difficulty,
                xp: $0.xp,
                time: $0.time.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    static func normalizeTitle(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns nil if validation fails.
    static func validateQuests(
        _ quests: [Quest],
        allowedCategories: [String],
        excludedNormalized: Set<String>,
        expectedCount: Int
    ) -> [Quest]? {
        let allowed = Set(allowedCategories)
        guard quests.count == expectedCount else { return nil }
        var seen = Set<String>()
        var out: [Quest] = []
        for q in quests {
            guard allowed.contains(q.category) else { return nil }
            let diffRaw = q.difficulty.trimmingCharacters(in: .whitespacesAndNewlines)
            let diff: String
            switch diffRaw.lowercased() {
            case "easy": diff = "Easy"
            case "medium": diff = "Medium"
            case "hard": diff = "Hard"
            default: return nil
            }
            let xp = min(100, max(25, q.xp))
            let title = q.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.count >= 8, title.count <= 220 else { return nil }
            let nt = normalizeTitle(title)
            guard !nt.isEmpty else { return nil }
            guard !excludedNormalized.contains(nt) else { return nil }
            guard !seen.contains(nt) else { return nil }
            seen.insert(nt)
            out.append(
                Quest(
                    category: q.category,
                    title: title,
                    difficulty: diff,
                    xp: xp,
                    time: q.time.isEmpty ? "10 min" : q.time
                )
            )
        }
        return out
    }
}
