import Foundation

// MARK: - Chat types used across the app
private func workerBase() throws -> URL {
    guard
      let raw = Bundle.main.object(forInfoDictionaryKey: "WORKER_URL") as? String,
      let url = URL(string: raw)
    else { throw URLError(.badURL) }
    return url
}

private func workerToken() -> String {
    (Bundle.main.object(forInfoDictionaryKey: "CLIENT_TOKEN") as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
}

enum ChatRole: String, Codable { case system, user, assistant }
struct ChatMessage: Codable { let role: ChatRole; let content: String }

// MARK: - Chat service (proxied via Cloudflare Worker through APIClient)

/// Требования:
///   • В Info.plist (таргет FinMind) задать:
///       WORKER_URL   = https://<твой>.workers.dev
///       CLIENT_TOKEN = <секрет>
///   • APIClient.workerChat(...) уже формирует запрос на /v1/chat/completions
///     и ставит заголовок x-client-token.
final class OpenAIChatService {
    static let shared = OpenAIChatService()
    private init() {}
    // Добавь внутрь OpenAIChatService
    @MainActor
    func debugPrintWorkerConfig() {
        do {
            let url = try workerBase()
            print("WORKER_URL =", url.absoluteString)
        } catch {
            print("WORKER_URL invalid:", error.localizedDescription)
        }

        let t = workerToken()
        print("CLIENT_TOKEN length:", t.count)
        if t.count > 6 {
            let preview = "\(t.prefix(3))...\(t.suffix(3))"
            print("CLIENT_TOKEN preview:", preview)
        } else {
            print("CLIENT_TOKEN preview:", t)
        }
    }

    /// Модель и температура передаются на воркер (см. APIClient.workerChat).
    var model: String = "gpt-4o-mini"
    var temperature: Double = 0

    /// Быстрый ping воркера (необязательная проверка доступности)
    @discardableResult
    func pingWorker() async -> Bool {
        await APIClient.shared.workerPing()
    }

    /// Нестримовый ответ (основной путь)
    func complete(messages: [ChatMessage], temperature: Double? = nil) async throws -> String {
        let reqTemp = temperature ?? self.temperature
        let payload = messages.map { APIClient.WorkerChatMessage(role: $0.role.rawValue, content: $0.content) }
        return try await APIClient.shared.workerChat(payload, temperature: reqTemp)
    }

    /// Удобный шорткат: один вопрос от пользователя (+ optional system)
    func ask(_ text: String, system: String? = nil, temperature: Double? = nil) async throws -> String {
        var msgs: [ChatMessage] = []
        if let system, !system.isEmpty { msgs.append(ChatMessage(role: .system, content: system)) }
        msgs.append(ChatMessage(role: .user, content: text))
        return try await complete(messages: msgs, temperature: temperature)
    }

    /// Заглушка для совместимости со старым API стриминга:
    /// воркер сейчас отдаёт полный ответ — имитируем поток единым чанком.
    func stream(messages: [ChatMessage],
                onDelta: @escaping (String) -> Void,
                onFinish: @escaping () -> Void) async throws {
        let text = try await complete(messages: messages)
        onDelta(text)
        onFinish()
    }
    @MainActor
    func diagnose400() async {
        do {
            let base = try workerBase() // читает WORKER_URL из Info.plist
            let url = base.appendingPathComponent("/v1/chat/completions")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            req.addValue(workerToken(), forHTTPHeaderField: "x-client-token") // читает CLIENT_TOKEN из Info.plist

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "user", "content": "Ответь только числом: 2+2"]
                ],
                "temperature": 0
            ]

            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("diagnose400 status =", status)
            print("diagnose400 body =", String(data: data, encoding: .utf8) ?? "<non-utf8>")

        } catch {
            print("diagnose400 error:", error.localizedDescription)
        }
    }
}
