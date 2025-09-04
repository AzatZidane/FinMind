import Foundation

/// Снимок курсов, достаточный для оценки сбережений в RUB.
struct RatesSnapshot {
    /// USD -> RUB
    let usdToRub: Double
    /// USD -> <валюта>, ключи — коды валют (например, "EUR", "CNY", ...). ВСЕ значения — сколько ЕДИНИЦ валюты за 1 USD.
    let fiatUSD: [String: Double]
    /// Цена 1 монеты в USD
    let cryptoUsd: [CryptoAsset: Double]
    /// Цена 1 тр. унции в USD
    let metalsUsd: [MetalAsset: Double]
    let updatedAt: Date
}

enum RatesError: Error, LocalizedError {
    case badResponse, decoding, network, missingRUB
    var errorDescription: String? {
        switch self {
        case .badResponse: return "Сервер вернул неверный ответ"
        case .decoding:    return "Не удалось разобрать данные курсов"
        case .network:     return "Сетевая ошибка"
        case .missingRUB:  return "Не получил курс USD/RUB"
        }
    }
}

final class RatesService {
    static let shared = RatesService()
    private init() {}

    // MARK: Public API

    /// Загружает все курсы. `fiatCodes` — какие фиат‑валюты понадобятся (например, ["RUB","USD","EUR","CNY","TRY"])
    func fetchAll(fiatCodes: [String]) async throws -> RatesSnapshot {
        async let fiatTask: [String: Double] = fetchFiatUSD(codes: fiatCodes)
        async let cryptoTask: [CryptoAsset: Double] = fetchCryptoUsd()
        async let metalsTask: [MetalAsset: Double] = fetchMetalsUsd()

        let fiat = try await fiatTask
        guard let usdToRub = fiat["RUB"], usdToRub > 0 else { throw RatesError.missingRUB }
        let crypto = try await cryptoTask
        let metals = try await metalsTask

        return RatesSnapshot(
            usdToRub: usdToRub,
            fiatUSD: fiat,
            cryptoUsd: crypto,
            metalsUsd: metals,
            updatedAt: Date()
        )
    }

    // MARK: FIAT

    /// Пытаемся получить курсы из open.er-api.com (USD -> *), при ошибке — из exchangerate.host
    private func fetchFiatUSD(codes: [String]) async throws -> [String: Double] {
        let wanted = Set(codes.map { $0.uppercased() }).union(["USD", "RUB"])
        // 1) Основной источник
        if let dict = try? await fetchFiatUSD_fromERAPI(),
           !dict.isEmpty {
            return dict.filter { wanted.contains($0.key) }
        }
        // 2) Фоллбэк
        let dict = try await fetchFiatUSD_fromExchangerateHost(codes: Array(wanted))
        return dict
    }

    /// open.er-api.com — JSON: { "rates": { "EUR": 0.91, "RUB": 95.0, ... } } — значения = currency per USD
    private func fetchFiatUSD_fromERAPI() async throws -> [String: Double] {
        struct Resp: Decodable { let result: String; let rates: [String: Double] }
        let url = URL(string: "https://open.er-api.com/v6/latest/USD")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        guard decoded.result == "success" else { throw RatesError.decoding }
        return decoded.rates
    }

    /// exchangerate.host — JSON: { "rates": { "RUB": 95.0, "EUR": 0.91, ... } } — тоже currency per USD
    private func fetchFiatUSD_fromExchangerateHost(codes: [String]) async throws -> [String: Double] {
        struct R: Decodable { let rates: [String: Double] }
        let symbols = codes.joined(separator: ",")
        let url = URL(string: "https://api.exchangerate.host/latest?base=USD&symbols=\(symbols)")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }
        let decoded = try JSONDecoder().decode(R.self, from: data)
        return decoded.rates
    }

    // MARK: CRYPTO

    /// CoinGecko simple/price
    private func fetchCryptoUsd() async throws -> [CryptoAsset: Double] {
        let ids = CryptoAsset.allCases.map { $0.coingeckoID }.joined(separator: ",")
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
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

    // MARK: METALS

    /// metals.live spot (USD/oz)
    private func fetchMetalsUsd() async throws -> [MetalAsset: Double] {
        let url = URL(string: "https://api.metals.live/v1/spot")!
        var req = URLRequest(url: url)
        req.setValue("FinMind/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }

        // Пример ответа: [{"gold": 1931.1}, {"silver": 24.0}, {"platinum": 920.1}, {"palladium": 1260.0}]
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Double]] ?? []
        var out: [MetalAsset: Double] = [:]
        for dict in arr {
            if let v = dict["gold"] { out[.xau] = v }
            if let v = dict["silver"] { out[.xag] = v }
            if let v = dict["platinum"] { out[.xpt] = v }
            if let v = dict["palladium"] { out[.xpd] = v }
        }
        return out
    }
}
