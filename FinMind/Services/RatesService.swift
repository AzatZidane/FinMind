import Foundation

/// Снимок курсов, достаточный чтобы посчитать стоимость сбережений в RUB
struct RatesSnapshot {
    let usdToRub: Double                 // сколько RUB за 1 USD
    let cryptoUsd: [CryptoAsset: Double] // $/coin
    let metalsUsd: [MetalAsset: Double]  // $/troy oz
    let updatedAt: Date
}

enum RatesError: Error { case badResponse, decoding, network }

final class RatesService {
    static let shared = RatesService()
    private init() {}

    // MARK: Public API

    func fetchAll() async throws -> RatesSnapshot {
        async let rub: Double = fetchUsdToRub()
        async let crypto: [CryptoAsset: Double] = fetchCryptoUsd()
        async let metals: [MetalAsset: Double] = fetchMetalsUsd()

        return try await RatesSnapshot(usdToRub: rub,
                                       cryptoUsd: crypto,
                                       metalsUsd: metals,
                                       updatedAt: Date())
    }

    // MARK: Sources

    /// exchangerate.host: USD -> RUB
    private func fetchUsdToRub() async throws -> Double {
        struct R: Decodable { let rates: [String: Double] }
        let url = URL(string: "https://api.exchangerate.host/latest?base=USD&symbols=RUB")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }
        let decoded = try JSONDecoder().decode(R.self, from: data)
        guard let rub = decoded.rates["RUB"] else { throw RatesError.decoding }
        return rub
    }

    /// CoinGecko simple/price по списку монет
    private func fetchCryptoUsd() async throws -> [CryptoAsset: Double] {
        let ids = CryptoAsset.allCases.map { $0.coingeckoID }.joined(separator: ",")
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd")!
        let (data, resp) = try await URLSession.shared.data(from: url)
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

    /// metals.live spot: XAU/XAG/XPT/XPD в USD за тройскую унцию
    private func fetchMetalsUsd() async throws -> [MetalAsset: Double] {
        let url = URL(string: "https://api.metals.live/v1/spot")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.badResponse }

        // Пример: [{"gold": 1929.41}, {"silver": 23.45}, {"platinum": 920.12}, {"palladium": 1260.9}]
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
