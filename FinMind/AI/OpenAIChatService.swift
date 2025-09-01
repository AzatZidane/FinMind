import Foundation

// MARK: - Chat types

enum ChatRole: String, Codable { case system, user, assistant }
struct ChatMessage: Codable { let role: ChatRole; let content: String }

enum OpenAIKeyError: LocalizedError {
    case missing
    var errorDescription: String? {
        "OPENAI_API_KEY не найден. При работе через прокси он не требуется в клиенте."
    }
}

// MARK: - Service

final class OpenAIChatService {
    // Параметры модели
    var model: String = "gpt-4o-mini"
    var temperature: Double = 0.2

    // --- ПРОКСИ (Render) ---
    private let useProxy = true
    private let proxyURL = URL(string: "https://finmind-proxy.onrender.com/v1/chat")!// ← замени на свой URL
    private let appToken: String = ProcessInfo.processInfo.environment["APP_TOKEN"] ?? ""

    // --- Прямой вызов OpenAI (если отключишь прокси) ---
    private let openAIURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    // Если когда‑нибудь решишь работать без прокси — понадобится ключ из окружения
    private func apiKey() throws -> String {
        if let k = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !k.isEmpty { return k }
        throw OpenAIKeyError.missing
    }

    // MARK: Public API

    /// Нестримовый ответ
    func complete(messages: [ChatMessage]) async throws -> String {
        let req = try makeRequest(messages: messages, stream: false)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp, data: data)
        let decoded = try JSONDecoder().decode(ChatCreateResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    /// Стриминг (SSE)
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
            if !appToken.isEmpty { req.setValue(appToken, forHTTPHeaderField: "X-App-Token") }
            // НИКАКОГО Authorization здесь — ключ хранится на сервере
        } else {
            req.setValue("Bearer \(try apiKey())", forHTTPHeaderField: "Authorization")
        }

        let body = ChatCreateRequest(model: model, messages: messages, temperature: temperature, stream: stream)
        req.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("→ Request URL:", url.absoluteString)
        print("→ Headers:", req.allHTTPHeaderFields ?? [:])
        #endif

        return req
    }

    // MARK: - Error handling

    private func validate(_ resp: URLResponse, data: Data? = nil) throws {
        guard let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        if let data = data, let env = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data) {
            throw NSError(domain: "OpenAI", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: env.error.message])
        } else {
            let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw NSError(domain: "OpenAI", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: text.isEmpty ? "HTTP \(http.statusCode)" : text])
        }
    }
}

// MARK: - DTO

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

private struct OpenAIErrorEnvelope: Decodable {
    struct OpenAIError: Decodable { let message: String; let type: String?; let code: String? }
    let error: OpenAIError
}
