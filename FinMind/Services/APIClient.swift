import Foundation

// MARK: - Errors

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

// MARK: - Base URL (симулятор vs устройство)

enum API {
#if targetEnvironment(simulator)
    // Симулятор на том же Mac
    static var baseURL: String = "http://127.0.0.1:8000"
#else
    // Реальное устройство в одной сети с ПК
    // ЗАМЕНИ на свой IPv4 (ipconfig): 192.168.0.105 — как у тебя сейчас
    static var baseURL: String = "http://192.168.0.105:8000"
#endif
}

// MARK: - Client

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 12
        c.timeoutIntervalForResource = 15
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()

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

    // MARK: - Endpoints

    /// Регистрация. Сервер сам проставляет created_at, мы шлём только id/email/nickname.
    func register(profile: UserProfile) async throws {
        guard let url = URL(string: "\(API.baseURL)/api/register") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = RegisterDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if status != 200 {
                AppLog.e("register bad status \(status)")
                throw APIError.badStatus(status)
            }
            if let ok = try? JSONDecoder().decode(OkDTO.self, from: data), ok.ok {
                return
            }
            throw APIError.decoding
        } catch {
            if let e = error as? URLError {
                AppLog.e("register URLError \(e.code.rawValue): \(e.localizedDescription)")
                if e.code == .appTransportSecurityRequiresSecureConnection {
                    // ATS блокирует http — подсказка в лог
                    AppLog.e("ATS: включите исключение в Info.plist (Debug) или используйте HTTPS")
                }
            } else {
                AppLog.e("register error: \(error.localizedDescription)")
            }
            throw APIError.network
        }
    }

    /// Обновление профиля (имя/почта).
    func updateProfile(profile: UserProfile) async throws {
        guard let url = URL(string: "\(API.baseURL)/api/update_profile") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = UpdateProfileDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if status != 200 {
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

    /// Отправка обратной связи (ID пользователя + текст).
    func sendFeedback(userId: String, message: String) async throws {
        guard let url = URL(string: "\(API.baseURL)/api/feedback") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = FeedbackDTO(user_id: userId, message: message)
        req.httpBody = try JSONEncoder().encode(dto)

        do {
            let (_, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if status != 200 {
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
enum APIClient {
    static let baseURL: URL = {
        guard
            let dict = Bundle.main.infoDictionary,
            let raw = dict["API_BASE_URL"] as? String,
            let url = URL(string: raw)
        else {
            fatalError("API_BASE_URL is missing in Info.plist")
        }
        return url
    }()
    // ... остальной код клиента
}

