import Foundation

/// Снимок курсов для расчёта стоимости сбережений в RUB
struct RatesSnapshot {
    /// Сколько RUB за 1 USD
    let usdToRub: Double
    /// Сколько ЕДИНИЦ валюты за 1 USD (ключ – код валюты: EUR, CNY, …)
    let fiatUSD: [String: Double]
    /// Цена 1 монеты в USD
    let cryptoUsd: [CryptoAsset: Double]
    /// Цена 1 тройской унции в USD
    let metalsUsd: [MetalAsset: Double]
    let updatedAt: Date
}

enum RatesError: Error, LocalizedError {
    case badResponse, decoding, network, missingRUB
    var errorDescription: String? {
        switch self {
        case .badResponse: return "Сервер вернул неверный статус"
        case .decoding:    return "Неверный формат данных от сервера"
        case .network:     return "Сетевая ошибка"
        case .missingRUB:  return "Не получил курс USD/RUB"
        }
    }
}

final class RatesService {
    static let shared = RatesService()
    private init() {}

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 12
        c.timeoutIntervalForResource = 12
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()

    // MARK: Public API

    /// Загружаем все нужные курсы. `fiatCodes` — список валют, которые хотим иметь (например: ["RUB","USD","EUR","CNY","TRY"])
    func fetchAll(fiatCodes: [String]) async throws -> RatesSnapshot {
        let fiat = try await fetchFiatUSD(codes: fiatCodes)
        guard let usdRub = fiat["RUB"], usdRub > 0 else { throw RatesError.missingRUB }

        // Крипта/металлы — «мягкие» источники: если не удалось, вернём пустые словари
        let crypto = (try? await fetchCryptoUsd()) ?? [:]
        let metals = (try? await fetchMetalsUsd()) ?? [:]

        return RatesSnapshot(
            usdToRub: usdRub,
            fiatUSD: fiat,
            cryptoUsd: crypto,
            metalsUsd: metals,
            updatedAt: Date()
        )
    }

    // MARK: - FIAT

    /// Пытаемся получить USD→* из нескольких источников, пока один не сработает.
    private func fetchFiatUSD(codes: [String]) async throws -> [String: Double] {
        let wanted = Set(codes.map { $0.uppercased() }).union(["USD","RUB"])

        if let dict = try? await fetchFiatUSD_fromERAPI(), !dict.isEmpty {
            return dict.filter { wanted.contains($0.key) }
        }
        if let dict = try? await fetchFiatUSD_fromFrankfurter(), !dict.isEmpty {
            return dict.filter { wanted.contains($0.key) }
        }
        if let dict = try? await fetchFiatUSD_fromExchangerateHost(codes: Array(wanted)), !dict.isEmpty {
            return dict
        }

        throw RatesError.network
    }

    /// open.er-api.com — {"rates": {...}}; значения бывают Double/Int/String — приводим к Double.
    private func fetchFiatUSD_fromERAPI() async throws -> [String: Double] {
        let url = URL(string: "https://open.er-api.com/v6/latest/USD")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }
        return try parseRatesDict(data: data, key: "rates")
    }

    /// frankfurter.app — {"rates": {...}} из базовой USD
    private func fetchFiatUSD_fromFrankfurter() async throws -> [String: Double] {
        let url = URL(string: "https://api.frankfurter.app/latest?from=USD")!
        let (data, resp) = try await session.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }
        return try parseRatesDict(data: data, key: "rates")
    }

    /// exchangerate.host — {"rates": {...}} c base=USD
    private func fetchFiatUSD_fromExchangerateHost(codes: [String]) async throws -> [String: Double] {
        let symbols = codes.joined(separator: ",")
        let url = URL(string: "https://api.exchangerate.host/latest?base=USD&symbols=\(symbols)")!
        let (data, resp) = try await session.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }
        return try parseRatesDict(data: data, key: "rates")
    }

    // MARK: - CRYPTO (CoinGecko)

    private func fetchCryptoUsd() async throws -> [CryptoAsset: Double] {
        let ids = CryptoAsset.allCases.map { $0.coingeckoID }.joined(separator: ",")
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var result: [CryptoAsset: Double] = [:]
        for asset in CryptoAsset.allCases {
            if let dict = json[asset.coingeckoID] as? [String: Any],
               let usd = dict["usd"] as? Double {
                result[asset] = usd
            }
        }
        return result
    }

    // MARK: - METALS (metals.live, несколько форматов + фоллбэки)

    private func fetchMetalsUsd() async throws -> [MetalAsset: Double] {
        // 1) Попробуем «общий» эндпоинт /v1/spot (форматы у них разнятся)
        if let dict = try? await parseMetalsFromSpotAll() {
            if !dict.isEmpty { return dict }
        }
        // 2) Фоллбэк: по одному металлу (/spot/gold, /spot/silver, ...)
        var out: [MetalAsset: Double] = [:]
        if let g = try? await fetchSingleMetal(path: "gold")      { out[.xau] = g }
        if let s = try? await fetchSingleMetal(path: "silver")     { out[.xag] = s }
        if let p = try? await fetchSingleMetal(path: "platinum")   { out[.xpt] = p }
        if let d = try? await fetchSingleMetal(path: "palladium")  { out[.xpd] = d }
        return out
    }

    /// Разные варианты ответа /v1/spot:
    ///  a) [{"gold":1934.1},{"silver":24.1},{"platinum":915.2},{"palladium":1200.3}]
    ///  b) [{"metal":"gold","price":1934.1,"currency":"USD"}, ...]
    ///  c) [{"gold":"1934.1"}, ...] — строки
    private func parseMetalsFromSpotAll() async throws -> [MetalAsset: Double] {
        let url = URL(string: "https://api.metals.live/v1/spot")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }

        let obj = try JSONSerialization.jsonObject(with: data)

        func toDouble(_ any: Any) -> Double? {
            if let d = any as? Double { return d }
            if let i = any as? Int    { return Double(i) }
            if let s = any as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
            return nil
        }

        var out: [MetalAsset: Double] = [:]

        // Вариант a/c: массив словарей с ключами gold/silver/...
        if let arr = obj as? [[String: Any]] {
            for dict in arr {
                if let v = dict["gold"],      let d = toDouble(v) { out[.xau] = d }
                if let v = dict["silver"],    let d = toDouble(v) { out[.xag] = d }
                if let v = dict["platinum"],  let d = toDouble(v) { out[.xpt] = d }
                if let v = dict["palladium"], let d = toDouble(v) { out[.xpd] = d }
                // Вариант b: {"metal":"gold","price":1934.1}
                if let metal = dict["metal"] as? String, let price = dict["price"], let d = toDouble(price) {
                    switch metal.lowercased() {
                    case "gold":      out[.xau] = d
                    case "silver":    out[.xag] = d
                    case "platinum":  out[.xpt] = d
                    case "palladium": out[.xpd] = d
                    default: break
                    }
                }
            }
        }
        return out
    }

    /// Фоллбэк: /v1/spot/{metal} — форма бывает:
    ///  • [1934.1, 1934.2, ...] — массив чисел; берём первый
    ///  • [{"price":1934.1}, ...] — массив словарей; ищем первое число в значениях
    private func fetchSingleMetal(path: String) async throws -> Double {
        let url = URL(string: "https://api.metals.live/v1/spot/\(path)")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }

        let obj = try JSONSerialization.jsonObject(with: data)

        func extractFirstNumber(from any: Any) -> Double? {
            if let d = any as? Double { return d }
            if let i = any as? Int    { return Double(i) }
            if let s = any as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
            if let dict = any as? [String: Any] {
                for v in dict.values {
                    if let n = extractFirstNumber(from: v) { return n }
                }
                return nil
            }
            if let arr = any as? [Any] {
                for el in arr {
                    if let n = extractFirstNumber(from: el) { return n }
                }
                return nil
            }
            return nil
        }

        if let arr = obj as? [Any], let first = arr.first, let n = extractFirstNumber(from: first) {
            return n
        }
        // если пришёл не массив — попробуем достать число из корня
        if let n = extractFirstNumber(from: obj) { return n }

        throw RatesError.decoding
    }

    // MARK: - Parser helper (для FIAT)

    /// Достаём словарь rates (любые типы) и приводим к [String: Double]
    private func parseRatesDict(data: Data, key: String) throws -> [String: Double] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any],
              let rates = root[key] as? [String: Any] else {
            throw RatesError.decoding
        }
        var out: [String: Double] = [:]
        for (k, v) in rates {
            if let d = v as? Double { out[k.uppercased()] = d }
            else if let i = v as? Int { out[k.uppercased()] = Double(i) }
            else if let s = v as? String,
                    let d = Double(s.replacingOccurrences(of: ",", with: ".")) {
                out[k.uppercased()] = d
            }
        }
        return out
    }
}
