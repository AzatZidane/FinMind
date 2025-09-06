import Foundation

enum APIError: LocalizedError {
    case badURL, badStatus(Int), decoding, network
    var errorDescription: String? {
        switch self {
        case .badURL: return "Неверный адрес сервера"
        case .badStatus(let c): return "Ошибка сервера (\(c))"
        case .decoding: return "Ошибка разбора ответа"
        case .network: return "Сетевая ошибка"
        }
    }
}

enum API {
#if targetEnvironment(simulator)
    static var baseURL: String = "http://127.0.0.1:8000"
#else
    static var baseURL: String = "http://192.168.0.105:8000" // IP твоего ПК в Wi-Fi сети
#endif
}


final class APIClient {
    static let shared = APIClient()
    private init() {}
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 10
        c.timeoutIntervalForResource = 15
        return URLSession(configuration: c)
    }()

    struct RegisterDTO: Codable {
        let id: String
        let email: String
        let nickname: String
        let createdAt: Date
    }
    struct OkDTO: Codable { let ok: Bool }

    func register(profile: UserProfile) async throws {
        guard let url = URL(string: "\(API.baseURL)/api/register") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let dto = RegisterDTO(id: profile.id, email: profile.email, nickname: profile.nickname, createdAt: profile.createdAt)
        req.httpBody = try JSONEncoder().encode(dto)

        AppLog.i(.network, "POST \(url.absoluteString)")

        do {
            let (data, resp) = try await session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            AppLog.i(.network, "status \(code), bytes=\(data.count)")
            guard code == 200 else { throw APIError.badStatus(code) }

            // простая проверка ok
            if let ok = try? JSONDecoder().decode(OkDTO.self, from: data), ok.ok == true {
                return
            }
            // если сервер вернул что-то иное — считаем ошибкой формата
            throw APIError.decoding
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.network
        }
    }
}
struct UpdateProfileDTO: Codable {
    let id: String
    let email: String
    let nickname: String
}
struct FeedbackDTO: Codable {
    let user_id: String
    let message: String
}

extension APIClient {
    func updateProfile(profile: UserProfile) async throws {
        guard let url = URL(string: "\(API.baseURL)/api/update_profile") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dto = UpdateProfileDTO(id: profile.id, email: profile.email, nickname: profile.nickname)
        req.httpBody = try JSONEncoder().encode(dto)

        let (data, resp) = try await session.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "UpdateProfile", code: code, userInfo: [NSLocalizedDescriptionKey: text])
        }
    }

    func sendFeedback(userId: String, message: String) async throws {
        guard let url = URL(string: "\(API.baseURL)/api/feedback") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dto = FeedbackDTO(user_id: userId, message: message)
        req.httpBody = try JSONEncoder().encode(dto)

        let (_, resp) = try await session.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 else {
            throw APIError.network
        }
    }
}
