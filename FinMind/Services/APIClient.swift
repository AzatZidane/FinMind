import Foundation

// MARK: - Ошибки верхнего уровня API
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
// Если в Info.plist нет API_BASE_URL — используем это значение.
enum API {
#if targetEnvironment(simulator)
    static var baseURL: String = "http://127.0.0.1:8000"
#else
    // ЗАМЕНИ при необходимости на свой IPv4 для локальной сети
    static var baseURL: String = "http://192.168.0.105:8000"
#endif
}

// MARK: - Единый сетевой клиент приложения
/// Приоритет выбора базового URL:
/// 1) Info.plist → ключ `API_BASE_URL` (prod/dev);
/// 2) Fallback из `API.baseURL` (симулятор/устройство).
final class APIClient {
    static let shared = APIClient()
    private init() {}

    // URLSession с аккуратными таймаутами
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
        // fallback (симулятор/девайс)
        guard let url = URL(string: API.baseURL) else {
            fatalError("Invalid fallback API.baseURL")
        }
        return url
    }

    // MARK: DTO
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

    // MARK: - Endpoints (твой бэкенд)
    /// Регистрация пользователя (server assigns created_at).
    func register(profile: UserProfile) async throws {
        let url = baseURL.appendingPathComponent("api/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = RegisterDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else {
                AppLog.e("register bad status \(status)")
                throw APIError.badStatus(status)
            }
            guard let ok = try? JSONDecoder().decode(OkDTO.self, from: data), ok.ok else {
                throw APIError.decoding
            }
        } catch {
            if let e = error as? URLError {
                AppLog.e("register URLError \(e.code.rawValue): \(e.localizedDescription)")
                if e.code == .appTransportSecurityRequiresSecureConnection {
                    AppLog.e("ATS: для http добавьте исключение в Info.plist (Debug) или используйте HTTPS")
                }
            } else {
                AppLog.e("register error: \(error.localizedDescription)")
            }
            throw APIError.network
        }
    }

    /// Обновление профиля.
    func updateProfile(profile: UserProfile) async throws {
        let url = baseURL.appendingPathComponent("api/update_profile")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = UpdateProfileDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else {
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
                AppLog.e("updateProfile bad status \(status) body: \(snippet)")
                throw APIError.badStatus(status)
            }
        } catch {
            if let e = error as? URLError {
                AppLog.e("updateProfile URLError \(e.code.rawValue): \(e.localizedDescription)")
            } else {
                AppLog.e("updateProfile error: \(error.localizedDescription)")
            }
            throw APIError.network
        }
    }

    /// Обратная связь (ID пользователя + текст сообщения).
    func sendFeedback(userId: String, message: String) async throws {
        let url = baseURL.appendingPathComponent("api/feedback")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = FeedbackDTO(user_id: userId, message: message)
        req.httpBody = try JSONEncoder().encode(dto)

        do {
            let (_, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else {
                AppLog.e("feedback bad status \(status)")
                throw APIError.badStatus(status)
            }
        } catch {
            if let e = error as? URLError {
                AppLog.e("feedback URLError \(e.code.rawValue): \(e.localizedDescription)")
            } else {
                AppLog.e("feedback error: \(error.localizedDescription)")
            }
            throw APIError.network
        }
    }
}

// MARK: - Worker config (чтение из Info.plist)
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

    #if DEBUG
    static func debugPrint() {
        let urlStr = baseURL?.absoluteString ?? "nil"
        print("[WorkerConfig] url=\(urlStr), tokenLen=\(token.count)")
    }
    #endif
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

// MARK: - Cloudflare Worker API (ping + chat)
// Требует в Info.plist: WORKER_URL (String), CLIENT_TOKEN (String)
extension APIClient {

    /// Сборка запроса к воркеру
    private func workerRequest(path: String,
                               method: String = "GET",
                               body: Data? = nil) throws -> URLRequest {
        #if DEBUG
        WorkerConfig.debugPrint()
        #endif

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

    /// GET /ping — проверка доступности воркера
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

    // DTO под OpenAI Chat Completions (через воркер)
    struct WorkerChatMessage: Codable { let role: String; let content: String }
    private struct WorkerChatRequest: Codable {
        let model: String
        let messages: [WorkerChatMessage]
        let temperature: Double?
    }
    private struct WorkerChatChoice: Codable { let index: Int; let message: WorkerChatMessage }
    private struct WorkerChatResponse: Codable { let choices: [WorkerChatChoice] }

    /// POST /v1/chat/completions — прокси через воркер на OpenAI
    func workerChat(_ messages: [WorkerChatMessage],
                    temperature: Double? = nil) async throws -> String {
        let payload = WorkerChatRequest(model: "gpt-4o-mini",
                                        messages: messages,
                                        temperature: temperature)
        let body = try JSONEncoder().encode(payload)
        let req  = try workerRequest(path: "v1/chat/completions",
                                     method: "POST",
                                     body: body)

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
