import Foundation

enum ChatRole: String, Codable { case system, user, assistant }
struct ChatMessage: Codable { let role: ChatRole; let content: String }

enum OpenAIKeyError: LocalizedError {
    case missing
    var errorDescription: String? {
        "OPENAI_API_KEY не найден. Если используешь прокси — эта переменная не нужна."
    }
}

final class OpenAIChatService {
    var model: String = "gpt-4o-mini"
    var temperature: Double = 0.2

    // --- Настройки прокси ---
    private let useProxy = true
    private let proxyURL = URL(string: "https://finmind-proxy.onrender.com/v1/chat")! // твой Render URL
    private let appToken = ProcessInfo.processInfo.environment["APP_TOKEN"] ?? ""

    // --- Прямой доступ (если прокси выключить) ---
    private let openAIURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    private func apiKey() throws -> String {
        if let k = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !k.isEmpty {
            return k
        }
        throw OpenAIKeyError.missing
    }

    // MARK: - Нестримоый ответ
    func complete(messages: [ChatMessage]) async throws -> String {
        let req = try makeRequest(messages: messages, stream: false)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp, data: data)
        let decoded = try JSONDecoder().decode(ChatCreateResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    // MARK: - Стриминг
    func stream(messages: [ChatMessage],
                onDelta: @escaping (String) -> Void,
                onFinish: @escaping () -> Void) async throws
    {
        let req = try makeRequest(messages: messages, stream: true)
        let (bytes, resp) = try await URLSession.shared.bytes(for: req)
        try validate(resp)

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

    // MARK: - Request builder
    private func makeRequest(messages: [ChatMessage], stream: Bool) throws -> URLRequest {
        let url = useProxy ? proxyURL : openAIURL
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if useProxy {
            if !appToken.isEmpty {
                req.setValue(appToken, forHTTPHeaderField: "X-App-Token")
            }
        } else {
            req.setValue("Bearer \(try apiKey())", forHTTPHeaderField: "Authorization")
        }

        let body = ChatCreateRequest(model: model,
                                     messages: messages,
                                     temperature: temperature,
                                     stream: stream)
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    private func validate(_ resp: URLResponse, data: Data? = nil) throws {
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw NSError(domain: "OpenAI",
                          code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: text])
        }
    }
}

// DTO
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
