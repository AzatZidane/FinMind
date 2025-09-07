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

// MARK: - Fallback base URL (симулятор vs устройство)
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
        c.timeoutIntervalForRequest = 12
        c.timeoutIntervalForResource = 15
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()

    // MARK: Base URL
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

    // DTO
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

    // MARK: - Твой бэкенд
    func register(profile: UserProfile) async throws {
        let url = baseURL.appendingPathComponent("api/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = RegisterDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            AppLog.e("register bad status \(status)")
            throw APIError.badStatus(status)
        }
        guard let ok = try? JSONDecoder().decode(OkDTO.self, from: data), ok.ok else {
            throw APIError.decoding
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

// MARK: - Конфиг воркера
private enum WorkerConfig {
    static let authHeader = "x-client-token"

    static var baseURL: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "WORKER_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return URL(string: raw)
    }

    static var token: String {
        (Bundle.main.object(forInfoDictionaryKey: "CLIENT_TOKEN") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func debugPrint() {
        let urlStr = baseURL?.absoluteString ?? "nil"
        let t = token
        let preview = t.isEmpty ? "EMPTY" : "\(t.prefix(3))…\(t.suffix(3))"
        print("[WorkerConfig] url=\(urlStr), tokenLen=\(t.count), tokenPreview=\(preview)")
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
    private func workerRequest(path: String,
                               method: String = "GET",
                               body: Data? = nil) throws -> URLRequest {
        WorkerConfig.debugPrint()

        guard let base = WorkerConfig.baseURL, !WorkerConfig.token.isEmpty else {
            throw WorkerError.missingConfig
        }
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(WorkerConfig.token, forHTTPHeaderField: WorkerConfig.authHeader)
        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        return req
    }

    @discardableResult
    func workerPing() async -> Bool {
        do {
            let req = try workerRequest(path: "ping")
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            AppLog.e("workerPing: \(error.localizedDescription)")
            return false
        }
    }

    struct WorkerChatMessage: Codable { let role: String; let content: String }
    private struct WorkerChatRequest: Codable {
        let model: String
        let messages: [WorkerChatMessage]
        let temperature: Double?
    }
    private struct WorkerChatChoice: Codable { let index: Int; let message: WorkerChatMessage }
    private struct WorkerChatResponse: Codable { let choices: [WorkerChatChoice] }

    func workerChat(_ messages: [WorkerChatMessage],
                    temperature: Double? = nil) async throws -> String {
        let payload = WorkerChatRequest(model: "gpt-4o-mini", messages: messages, temperature: temperature)
        let body = try JSONEncoder().encode(payload)
        let req  = try workerRequest(path: "v1/chat/completions", method: "POST", body: body)

        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        if code == 401 { throw WorkerError.unauthorized }
        guard code == 200 else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            AppLog.e("workerChat status \(code) body: \(snippet)")
            throw WorkerError.badStatus(code)
        }
        let decoded = try JSONDecoder().decode(WorkerChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }
}
