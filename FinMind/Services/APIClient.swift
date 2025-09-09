//
//  APIClient.swift
//  FinMind
//
//  Обновлено:
//  - Убран HMAC и кастомные заголовки; используем x-client-token из Info.plist
//  - Воркера зовём по пути /v1/chat/completions (а не /v1/advise)
//  - Правильный JSON: { model, messages: [ {role, content} ], temperature, max_tokens? }
//  - Пинг воркера: GET /healthz
//

import Foundation

// MARK: - Верхнеуровневые ошибки API
enum APIError: LocalizedError {
    case badURL
    case badStatus(Int)
    case decoding
    case network

    var errorDescription: String? {
        switch self {
        case .badURL: return "Неверный адрес сервера"
        case .badStatus(let s): return "Ошибка сервера (\(s))"
        case .decoding: return "Ошибка формата ответа"
        case .network: return "Сетевая ошибка"
        }
    }
}

// MARK: - Fallback base URL (симулятор vs устройство) — для твоего бэкенда, не для воркера
enum API {
#if targetEnvironment(simulator)
    static var baseURL: String = "http://127.0.0.1:8000"
#else
    static var baseURL: String = "http://192.168.0.105:8000" // замени на свой IP при отладке
#endif
}

// MARK: - Единый сетевой клиент приложения
final class APIClient {
    static let shared = APIClient()
    private init() {}

    let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        c.timeoutIntervalForResource = 30
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()

    // MARK: Base URL твоего бэкенда (не воркера)
    private var baseURL: URL {
        if
            let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: raw)
        {
            return url
        }
        guard let url = URL(string: API.baseURL) else {
            fatalError("Invalid fallback API.baseURL")
        }
        return url
    }

    // === DTO для твоего бэкенда (как было ранее) ===
    private struct RegisterDTO: Codable {
        let id: String
        let email: String
        let nickname: String
    }
    private struct UpdateProfileDTO: Codable {
        let id: String
        let email: String
        let nickname: String
    }
    private struct FeedbackDTO: Codable {
        let user_id: String
        let message: String
    }
    private struct OkDTO: Codable { let ok: Bool }

    // MARK: - Примеры методов твоего бэкенда (оставлены как были)

    func register(profile: UserProfile) async throws {
        let url = baseURL.appendingPathComponent("api/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = RegisterDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1

        struct ErrBody: Codable { let error: String?; let detail: String? }

        if code != 200 {
            if let eb = try? JSONDecoder().decode(ErrBody.self, from: data) {
                let human = eb.detail ?? eb.error ?? "unknown"
                AppLog.e("register status \(code): \(human)")
                if code == 401 { throw WorkerError.unauthorized }
                throw WorkerError.badStatus(code)
            } else {
                let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
                AppLog.e("register status \(code) body: \(snippet)")
                if code == 401 { throw WorkerError.unauthorized }
                throw WorkerError.badStatus(code)
            }
        }
    }

    func updateProfile(profile: UserProfile) async throws {
        let url = baseURL.appendingPathComponent("api/update_profile")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = UpdateProfileDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
            AppLog.e("updateProfile bad status \(status) body: \(snippet)")
            throw APIError.badStatus(status)
        }
    }

    func sendFeedback(userId: String, message: String) async throws {
        let url = baseURL.appendingPathComponent("api/feedback")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = FeedbackDTO(user_id: userId, message: message)
        req.httpBody = try JSONEncoder().encode(dto)

        let (_, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            AppLog.e("feedback bad status \(status)")
            throw APIError.badStatus(status)
        }
    }
}

// MARK: - Конфиг воркера (Cloudflare)
private enum WorkerConfig {
    /// WORKER_URL — базовый URL воркера в Info.plist, без путей.
    /// Пример: https://late-mode-309f.azatzidane.workers.dev
    static var baseURL: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "WORKER_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = URL(string: raw) else { fatalError("WORKER_URL not set") }
        return url
    }

    /// CLIENT_TOKEN — тот же секрет, что в Variables у воркера.
    static var token: String {
        (Bundle.main.object(forInfoDictionaryKey: "CLIENT_TOKEN") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private enum WorkerError: LocalizedError {
    case missingConfig, unauthorized, badStatus(Int)
    var errorDescription: String? {
        switch self {
        case .missingConfig: return "WORKER_URL/CLIENT_TOKEN не заданы."
        case .unauthorized:  return "Неверный CLIENT_TOKEN (401)."
        case .badStatus(let s): return "Ошибка воркера (\(s))."
        }
    }
}

// MARK: - Воркеры (ping + chat)
extension APIClient {

    /// GET /healthz → true/false
    @discardableResult
    func workerPing() async -> Bool {
        do {
            var req = URLRequest(url: WorkerConfig.baseURL.appendingPathComponent("/healthz"))
            req.httpMethod = "GET"
            let (_, resp) = try await session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            return code == 200
        } catch {
            AppLog.e("workerPing: \(error.localizedDescription)")
            return false
        }
    }

    // Формат сообщений для OpenAI
    struct WorkerChatMessage: Codable {
        let role: String   // "system" | "user" | "assistant"
        let content: String
    }

    /// Основной вызов к воркеру → OpenAI Chat Completions
    /// Возвращает текст первого ответа.
    func workerChat(_ messages: [WorkerChatMessage],
                    temperature: Double = 0.2,
                    model: String = "gpt-4o-mini",
                    maxTokens: Int? = nil) async throws -> String {

        // Санитизация: выкинем пустые строки
        let msgs = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !msgs.isEmpty else { throw WorkerError.badStatus(400) }

        let temp = clampTemp(temperature)

        // Сборка запроса
        var req = URLRequest(url: WorkerConfig.baseURL.appendingPathComponent("/v1/chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(WorkerConfig.token, forHTTPHeaderField: "x-client-token")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        // Тело: обязательно "messages"
        struct Body: Encodable {
            let model: String
            let messages: [WorkerChatMessage]
            let temperature: Double
            let max_tokens: Int?
        }
        let body = Body(model: model, messages: msgs, temperature: temp, max_tokens: maxTokens)
        req.httpBody = try JSONEncoder().encode(body)

        // Отправка
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        print("[API] workerChat status =", status)

        guard (200..<300).contains(status) else {
            let txt = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[API] workerChat error body:", txt)
            if status == 401 { throw WorkerError.unauthorized }
            throw WorkerError.badStatus(status)
        }

        // Мини-декодер OpenAI
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let role: String; let content: String? }
                let index: Int
                let message: Msg
            }
            let choices: [Choice]
        }

        let res = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = res.choices.first?.message.content, !text.isEmpty else {
            throw APIError.decoding
        }
        return text
    }

    // Утилиты
    private func clampTemp(_ t: Double) -> Double {
        guard t.isFinite else { return 0.2 }
        return min(2.0, max(0.0, t))
    }
}
