//
//  APIClient.swift
//  FinMind
//
//  Полностью обновлён: добавлена HMAC-авторизация для Cloudflare Worker,
//  исправлен путь на /v1/advise и формат запроса/ответа воркера.
//  (замена прежней версии файла) // основано на текущем проекте:contentReference[oaicite:0]{index=0}
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

// MARK: - Конфиг воркера (HMAC авторизация)
import CryptoKit
import UIKit

private enum WorkerConfig {
    /// WORKER_URL должен быть полным до хоста, без пути. Пример:
    /// https://late-mode-309f.azatzidane.workers.dev
    static var baseURL: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "WORKER_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return URL(string: raw)
    }

    /// CLIENT_TOKEN — общий секрет (совпадает со значением секрета в Cloudflare)
    static var secret: String {
        (Bundle.main.object(forInfoDictionaryKey: "CLIENT_TOKEN") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Заголовки авторизации для воркера: X-FM-Token/TS/Bundle/Device
    static func makeHeaders() -> [String: String]? {
        guard !secret.isEmpty else { return nil }

        let ts = Int64(Date().timeIntervalSince1970)
        let bundle = Bundle.main.bundleIdentifier ?? "unknown.bundle"
        let device = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        let message = "\(bundle).\(device).\(ts)"

        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let token = Data(mac).base64EncodedString() // ожидаемая длина 44

        // Debug-вывод как в логе
        let preview = token.prefix(3) + "…" + token.suffix(3)
        print("[WorkerConfig] url=\(baseURL?.absoluteString ?? "nil"), tokenLen=\(token.count), tokenPreview=\(preview)")

        return [
            "X-FM-Token": token,
            "X-FM-TS": String(ts),
            "X-FM-Bundle": bundle,
            "X-FM-Device": device,
            "Content-Type": "application/json"
        ]
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
        guard let base = WorkerConfig.baseURL else {
            throw WorkerError.missingConfig
        }
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        guard let headers = WorkerConfig.makeHeaders() else {
            throw WorkerError.missingConfig
        }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body = body {
            req.httpBody = body
            // Content-Type уже поставлен в makeHeaders(), оставим как есть
        }
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        return req
    }

    /// Быстрый ping: используем CORS preflight на /v1/advise (возвращает 204 при успехе)
    @discardableResult
    func workerPing() async -> Bool {
        do {
            let req = try workerRequest(path: "v1/advise", method: "OPTIONS")
            let (_, resp) = try await session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            return code == 204 || code == 200
        } catch {
            AppLog.e("workerPing: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Chat → /v1/advise

    struct WorkerChatMessage: Codable { let role: String; let content: String }

    /// Параметры, которые ждёт воркер (упрощённый формат)
    private struct WorkerAdviseRequest: Codable {
        let text: String
        let system: String?
        let model: String?
        let temperature: Double?
    }

    /// Ответ воркера: { reply, model } или { error, detail }
    private struct WorkerAdviseResponse: Codable {
        let reply: String?
        let model: String?
        let error: String?
        let detail: String?
    }

    func workerChat(_ messages: [WorkerChatMessage],
                    temperature: Double? = nil) async throws -> String {
        // Вытащим system и последний user — под формат воркера
        let systemText = messages.first(where: { $0.role.lowercased() == "system" })?.content
        let userText = messages.last(where: { $0.role.lowercased() == "user" })?.content
            ?? messages.map(\.content).joined(separator: "\n")

        let payload = WorkerAdviseRequest(
            text: userText,
            system: systemText,
            model: "gpt-4o-mini",
            temperature: temperature
        )

        let body = try JSONEncoder().encode(payload)
        let req  = try workerRequest(path: "v1/advise", method: "POST", body: body)

        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1

        if code == 401 { throw WorkerError.unauthorized }
        guard code == 200 else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            AppLog.e("workerChat status \(code) body: \(snippet)")
            throw WorkerError.badStatus(code)
        }

        let decoded = try JSONDecoder().decode(WorkerAdviseResponse.self, from: data)
        if let reply = decoded.reply { return reply }

        // На всякий случай: если ответа нет, но воркер вернул описание ошибки
        if let err = decoded.error ?? decoded.detail {
            AppLog.e("workerChat logical error: \(err)")
        }
        return ""
    }
}
