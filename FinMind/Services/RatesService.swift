import Foundation

// MARK: - Model

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

// MARK: - Service

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

    /// Загружаем все нужные курсы. `fiatCodes` — список валют, которые хотим иметь (например: ["RUB","USD","EUR","CNY","TRY"])
    func fetchAll(fiatCodes: [String]) async throws -> RatesSnapshot {
        AppLog.i(.rates, "fetchAll start (fiatCodes=\(fiatCodes.joined(separator: ",")))")

        let fiat = try await fetchFiatUSD(codes: fiatCodes)
        guard let usdRub = fiat["RUB"], usdRub > 0 else { AppLog.e("missingRUB"); throw RatesError.missingRUB }

        let crypto = (try? await fetchCryptoUsd()) ?? [:]
        let metals = (try? await fetchMetalsUsd()) ?? [:]

        AppLog.i(.rates, "result: usdRub=\(usdRub), fiat=\(fiat.count) keys, crypto=\(crypto.count), metals=\(metals.count)")

        return RatesSnapshot(
            usdToRub: usdRub,
            fiatUSD: fiat,
            cryptoUsd: crypto,
            metalsUsd: metals,
            updatedAt: Date()
        )
    }

    // MARK: - FIAT

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

        AppLog.e("FIAT: all sources failed")
        throw RatesError.network
    }

    /// open.er-api.com — {"rates": {...}}; значения бывают Double/Int/String — приводим к Double.
    private func fetchFiatUSD_fromERAPI() async throws -> [String: Double] {
        let url = URL(string: "https://open.er-api.com/v6/latest/USD")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(for: req)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }
        let parsed = try parseRatesDict(data: data, key: "rates")
        AppLog.i(.rates, "ERAPI parsed keys=\(parsed.count)")
        return parsed
    }

    /// frankfurter.app — {"rates": {...}} из базовой USD
    private func fetchFiatUSD_fromFrankfurter() async throws -> [String: Double] {
        let url = URL(string: "https://api.frankfurter.app/latest?from=USD")!
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(from: url)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }
        let parsed = try parseRatesDict(data: data, key: "rates")
        AppLog.i(.rates, "Frankfurter parsed keys=\(parsed.count)")
        return parsed
    }

    /// exchangerate.host — {"rates": {...}} c base=USD
    private func fetchFiatUSD_fromExchangerateHost(codes: [String]) async throws -> [String: Double] {
        let symbols = codes.joined(separator: ",")
        let url = URL(string: "https://api.exchangerate.host/latest?base=USD&symbols=\(symbols)")!
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(from: url)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }
        let parsed = try parseRatesDict(data: data, key: "rates")
        AppLog.i(.rates, "ERHost parsed keys=\(parsed.count)")
        return parsed
    }

    // MARK: - CRYPTO (CoinGecko)

    private func fetchCryptoUsd() async throws -> [CryptoAsset: Double] {
        let ids = CryptoAsset.allCases.map { $0.coingeckoID }.joined(separator: ",")
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(for: req)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var result: [CryptoAsset: Double] = [:]
        for asset in CryptoAsset.allCases {
            if let dict = json[asset.coingeckoID] as? [String: Any],
               let usd = dict["usd"] as? Double {
                result[asset] = usd
            }
        }
        AppLog.i(.rates, "Crypto parsed assets=\(result.count)")
        return result
    }

    // MARK: - METALS

    /// Основной источник — exchangerate.host: base = XAU/XAG/XPT/XPD → symbols = USD.
    /// Возвращает USD за 1 тр. унцию. Фоллбэки — metals.live.
    private func fetchMetalsUsd() async throws -> [MetalAsset: Double] {
        AppLog.i(.metals, "fetch metals (exchangerate.host)")
        async let xau = fetchMetalUSD_fromERHost(base: "XAU")
        async let xag = fetchMetalUSD_fromERHost(base: "XAG")
        async let xpt = fetchMetalUSD_fromERHost(base: "XPT")
        async let xpd = fetchMetalUSD_fromERHost(base: "XPD")

        var out: [MetalAsset: Double] = [:]
        do { if let v = try await xau { out[.xau] = v } } catch { AppLog.e("XAU err: \(error.localizedDescription)") }
        do { if let v = try await xag { out[.xag] = v } } catch { AppLog.e("XAG err: \(error.localizedDescription)") }
        do { if let v = try await xpt { out[.xpt] = v } } catch { AppLog.e("XPT err: \(error.localizedDescription)") }
        do { if let v = try await xpd { out[.xpd] = v } } catch { AppLog.e("XPD err: \(error.localizedDescription)") }

        AppLog.i(.metals, "ERHost metals parsed=\(out)")

        if !out.isEmpty { return out }

        // Фоллбэк #1: общий /v1/spot
        AppLog.i(.metals, "fallback metals.live common")
        if let dict = try? await parseMetalsFromSpotAll(), !dict.isEmpty {
            AppLog.i(.metals, "metals.live common parsed=\(dict)")
            return dict
        }
        // Фоллбэк #2: по одному металлу
        AppLog.i(.metals, "fallback metals.live per‑metal")
        var fb: [MetalAsset: Double] = [:]
        if let g2 = try? await fetchSingleMetal(path: "gold")      { fb[.xau] = g2 }
        if let s2 = try? await fetchSingleMetal(path: "silver")     { fb[.xag] = s2 }
        if let p2 = try? await fetchSingleMetal(path: "platinum")   { fb[.xpt] = p2 }
        if let d2 = try? await fetchSingleMetal(path: "palladium")  { fb[.xpd] = d2 }
        AppLog.i(.metals, "metals.live per‑metal parsed=\(fb)")
        return fb
    }

    private func fetchMetalUSD_fromERHost(base: String) async throws -> Double? {
        let url = URL(string: "https://api.exchangerate.host/latest?base=\(base)&symbols=USD")!
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(from: url)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }
        let dict = try parseRatesDict(data: data, key: "rates")
        let usd = dict["USD"]
        AppLog.i(.metals, "\(base) -> USD = \(usd ?? -1)")
        return usd
    }

    // ---- metals.live helpers ----

    private func parseMetalsFromSpotAll() async throws -> [MetalAsset: Double] {
        let url = URL(string: "https://api.metals.live/v1/spot")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(for: req)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }

        let obj = try JSONSerialization.jsonObject(with: data)

        func toDouble(_ any: Any) -> Double? {
            if let d = any as? Double { return d }
            if let i = any as? Int    { return Double(i) }
            if let s = any as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
            return nil
        }

        var out: [MetalAsset: Double] = [:]
        if let arr = obj as? [[String: Any]] {
            for dict in arr {
                if let v = dict["gold"],      let d = toDouble(v) { out[.xau] = d }
                if let v = dict["silver"],    let d = toDouble(v) { out[.xag] = d }
                if let v = dict["platinum"],  let d = toDouble(v) { out[.xpt] = d }
                if let v = dict["palladium"], let d = toDouble(v) { out[.xpd] = d }
                if let metal = dict["metal"] as? String, let price = dict["price"], let d = toDouble(price) {
                    switch metal.lowercased() {
                    case "gold": out[.xau] = d
                    case "silver": out[.xag] = d
                    case "platinum": out[.xpt] = d
                    case "palladium": out[.xpd] = d
                    default: break
                    }
                }
            }
        }
        return out
    }

    private func fetchSingleMetal(path: String) async throws -> Double {
        let url = URL(string: "https://api.metals.live/v1/spot/\(path)")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(for: req)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }

        let obj = try JSONSerialization.jsonObject(with: data)

        func extractFirstNumber(from any: Any) -> Double? {
            if let d = any as? Double { return d }
            if let i = any as? Int    { return Double(i) }
            if let s = any as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
            if let dict = any as? [String: Any] {
                for v in dict.values { if let n = extractFirstNumber(from: v) { return n } }
                return nil
            }
            if let arr = any as? [Any] {
                for el in arr { if let n = extractFirstNumber(from: el) { return n } }
                return nil
            }
            return nil
        }

        if let arr = obj as? [Any], let first = arr.first, let n = extractFirstNumber(from: first) { return n }
        if let n = extractFirstNumber(from: obj) { return n }
        throw RatesError.decoding
    }

    // MARK: - helpers

    private func parseRatesDict(data: Data, key: String) throws -> [String: Double] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any],
              let rates = root[key] as? [String: Any] else {
            AppLog.e("parseRatesDict: root or key not found")
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

    private func logBodySample(_ data: Data) throws {
        // только первые 500 символов, чтобы не «забивать» лог
        let s = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes binary>"
        let sample = s.prefix(500).replacingOccurrences(of: "\n", with: " ")
        AppLog.i(.network, "body: \(sample)")
    }
}
