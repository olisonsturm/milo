import Foundation

enum LLMFormat: String, CaseIterable {
    case responses = "OpenAI Responses"
    case chat = "OpenAI-kompatibel (Chat)"
    case claude = "Claude Messages"

    var path: String {
        switch self { case .responses: return "responses"; case .chat: return "chat/completions"; case .claude: return "messages" }
    }
}

struct LLMConfiguration {
    var format: LLMFormat = .responses
    var baseURL = "https://api.openai.com/v1"
    var model = "gpt-4.1-mini"

    static var current: LLMConfiguration {
        let defaults = UserDefaults.standard
        return LLMConfiguration(format: LLMFormat(rawValue: defaults.string(forKey: "milo.llm.format") ?? "") ?? .responses,
                                baseURL: defaults.string(forKey: "milo.llm.baseURL") ?? "https://api.openai.com/v1",
                                model: defaults.string(forKey: "milo.llm.model") ?? "gpt-4.1-mini")
    }

    func save() {
        UserDefaults.standard.set(format.rawValue, forKey: "milo.llm.format")
        UserDefaults.standard.set(baseURL, forKey: "milo.llm.baseURL")
        UserDefaults.standard.set(model, forKey: "milo.llm.model")
    }

    func endpoint() throws -> URL {
        guard let parts = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.scheme == "https" || (parts.scheme == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)),
              var url = parts.url else { throw AssistantCore.Failure.configuration }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix(format.path) { return url }
        if path.isEmpty { url.appendPathComponent("v1") }
        url.appendPathComponent(format.path)
        return url
    }

    var isDirectOpenAI: Bool {
        (try? endpoint().absoluteString) == "https://api.openai.com/v1/responses"
    }

    var key: String? {
        guard let scope = try? endpoint().absoluteString else { return nil }
        return isDirectOpenAI ? Keychain.get(.openai) : Keychain.getLLMKey(scope: scope)
    }

    func setKey(_ value: String?) {
        guard let scope = try? endpoint().absoluteString else { return }
        if isDirectOpenAI { Keychain.set(.openai, value) }
        else { Keychain.setLLMKey(scope: scope, value: value) }
    }
}

/// Don't forward proxy credentials to another endpoint through an HTTP redirect.
final class LLMRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
