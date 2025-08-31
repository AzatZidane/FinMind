import Foundation

enum ChatRole: String, Codable { case system, user, assistant }
struct ChatMessage: Codable { let role: ChatRole; let content: String }

enum OpenAIKeyError: LocalizedError {
    case missing
    var errorDescription: String? {
        "OpenAI API key is missing. Set OPENAI_API_KEY env var or add it to Keychain (service=OpenAI, account=default)."
    }
}

final class OpenAIChatService {
    var model: String = "gpt-4o-mini"
    var temperature: Double = 0.2
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private func apiKey() throws -> String {
        if let env = ProcessInfo.processInfo.environment["***REMOVED***"], !env.isEmpty {
            return env
        }
        if let key = try? KeychainHelper.shared.read(service: "OpenAI", account: "default"), !key.isEmpty {
            return key
        }
        throw OpenAIKeyError.missing
    }

    func complete(messages: [ChatMessage]) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(try apiKey())", forHTTPHeaderField: "Authorization")

        let body = ChatCreateRequest(model: model, messages: messages, temperature: temperature, stream: nil)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try validateHTTP(resp)
        let decoded = try JSONDecoder().decode(ChatCreateResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    func stream(messages: [ChatMessage],
                onDelta: @escaping (String) -> Void,
                onFinish: @escaping () -> Void) async throws {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(try apiKey())", forHTTPHeaderField: "Authorization")

        let body = ChatCreateRequest(model: model, messages: messages, temperature: temperature, stream: true)
        req.httpBody = try JSONEncoder().encode(body)

        let (bytes, resp) = try await URLSession.shared.bytes(for: req)
        try validateHTTP(resp)

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }
            if let data = payload.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(ChatStreamChunk.self, from: data),
               let piece = chunk.choices.first?.delta.content {
                onDelta(piece)
            }
        }
        onFinish()
    }

    private func validateHTTP(_ resp: URLResponse) throws {
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "OpenAI", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
    }
}

// --- DTO ниже без изменений ---
private struct ChatCreateRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let stream: Bool?
}

private struct ChatCreateResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { let role: ChatRole; let content: String }
        let index: Int
        let message: Message
        let finish_reason: String?
    }
    let id: String
    let object: String
    let created: Int
    let choices: [Choice]
}

private struct ChatStreamChunk: Codable {
    struct Choice: Codable {
        struct Delta: Codable { let role: ChatRole?; let content: String? }
        let index: Int
        let delta: Delta
        let finish_reason: String?
    }
    let id: String
    let object: String
    let created: Int
    let choices: [Choice]
}
