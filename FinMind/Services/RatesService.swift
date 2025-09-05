import Foundation

// MARK: - Model

struct RatesSnapshot {
    let usdToRub: Double                  // RUB за 1 USD
    let fiatUSD: [String: Double]         // currency per USD: ["EUR": 0.92, ...]
    let cryptoUsd: [CryptoAsset: Double]  // $/coin
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

    func fetchAll(fiatCodes: [String]) async throws -> RatesSnapshot {
        AppLog.i(.rates, "fetchAll start (fiatCodes=\(fiatCodes.joined(separator: ",")))")

        let fiat = try await fetchFiatUSD(codes: fiatCodes)
        guard let usdRub = fiat["RUB"], usdRub > 0 else { AppLog.e("missingRUB"); throw RatesError.missingRUB }

        let crypto = (try? await fetchCryptoUsd()) ?? [:]

        AppLog.i(.rates, "result: usdRub=\(usdRub), fiat=\(fiat.count) keys, crypto=\(crypto.count)")

        return RatesSnapshot(
            usdToRub: usdRub,
            fiatUSD: fiat,
            cryptoUsd: crypto,
            updatedAt: Date()
        )
    }

    // MARK: FIAT

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
        return try parseRatesDict(data: data, key: "rates")
    }

    private func fetchFiatUSD_fromFrankfurter() async throws -> [String: Double] {
        let url = URL(string: "https://api.frankfurter.app/latest?from=USD")!
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(from: url)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }
        return try parseRatesDict(data: data, key: "rates")
    }

    private func fetchFiatUSD_fromExchangerateHost(codes: [String]) async throws -> [String: Double] {
        let symbols = codes.joined(separator: ",")
        let url = URL(string: "https://api.exchangerate.host/latest?base=USD&symbols=\(symbols)")!
        AppLog.i(.network, "GET \(url.absoluteString)")
        let (data, resp) = try await session.data(from: url)
        let sc = (resp as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.i(.network, "status \(sc), bytes=\(data.count)")
        try logBodySample(data)
        guard sc == 200 else { throw RatesError.badResponse }
        return try parseRatesDict(data: data, key: "rates")
    }

    // MARK: CRYPTO

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

    // MARK: helpers

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
        let s = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes binary>"
        let sample = s.prefix(500).replacingOccurrences(of: "\n", with: " ")
        AppLog.i(.network, "body: \(sample)")
    }
}
