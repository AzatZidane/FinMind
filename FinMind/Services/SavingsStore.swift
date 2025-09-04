import Foundation
import Combine

// Поддерживаемые криптоактивы
enum CryptoAsset: String, CaseIterable, Identifiable, Codable {
    case btc, eth, usdt, usdc, bnb, sol, ton
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .btc: return "BTC"
        case .eth: return "ETH"
        case .usdt: return "USDT"
        case .usdc: return "USDC"
        case .bnb: return "BNB"
        case .sol: return "SOL"
        case .ton: return "TON"
        }
    }
    var title: String {
        switch self {
        case .btc: return "Bitcoin (BTC)"
        case .eth: return "Ethereum (ETH)"
        case .usdt: return "Tether (USDT)"
        case .usdc: return "USD Coin (USDC)"
        case .bnb: return "BNB (BNB)"
        case .sol: return "Solana (SOL)"
        case .ton: return "Toncoin (TON)"
        }
    }
    var coingeckoID: String {
        switch self {
        case .btc: return "bitcoin"
        case .eth: return "ethereum"
        case .usdt: return "tether"
        case .usdc: return "usd-coin"
        case .bnb: return "binancecoin"
        case .sol: return "solana"
        case .ton: return "toncoin"
        }
    }
}

// Драгоценные металлы (количество храним в граммах)
enum MetalAsset: String, CaseIterable, Identifiable, Codable {
    case xau, xag, xpt, xpd
    var id: String { rawValue }
    var title: String {
        switch self {
        case .xau: return "Золото (XAU)"
        case .xag: return "Серебро (XAG)"
        case .xpt: return "Платина (XPT)"
        case .xpd: return "Палладий (XPD)"
        }
    }
}

// Быстрый доступ к валюте по коду
extension Currency {
    static func by(code: String) -> Currency? {
        Currency.supported.first { $0.code.uppercased() == code.uppercased() }
    }
}

final class SavingsStore: ObservableObject {
    static let shared = SavingsStore()

    // Публичные данные
    @Published var cryptoHoldings: [CryptoAsset: Double]   // количество монет
    @Published var metalGrams: [MetalAsset: Double]        // граммы металлов
    // Фиат: сумма в валюте, ключ — код валюты (EUR, USD, RUB, ...)
    @Published private(set) var fiat: [String: Double]

    private var cancellables = Set<AnyCancellable>()
    private let ud = UserDefaults.standard

    private init() {
        // CRYPTO
        if let data = ud.data(forKey: "savings.crypto"),
           let decoded = try? JSONDecoder().decode([CryptoAsset: Double].self, from: data) {
            cryptoHoldings = decoded
        } else {
            cryptoHoldings = Dictionary(uniqueKeysWithValues: CryptoAsset.allCases.map { ($0, 0) })
        }

        // METALS
        if let data = ud.data(forKey: "savings.metals"),
           let decoded = try? JSONDecoder().decode([MetalAsset: Double].self, from: data) {
            metalGrams = decoded
        } else {
            metalGrams = Dictionary(uniqueKeysWithValues: MetalAsset.allCases.map { ($0, 0) })
        }

        // FIAT (храним как [код: сумма])
        if let data = ud.data(forKey: "savings.fiat"),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            fiat = decoded
        } else {
            // дефолтный набор
            let defaultCodes = ["RUB","USD","EUR","CNY","TRY"]
            fiat = Dictionary(uniqueKeysWithValues: defaultCodes.map { ($0, 0.0) })
        }

        // Автосохранение
        $cryptoHoldings
            .sink { [weak self] dict in
                guard let self = self else { return }
                if let data = try? JSONEncoder().encode(dict) {
                    self.ud.set(data, forKey: "savings.crypto")
                }
            }
            .store(in: &cancellables)

        $metalGrams
            .sink { [weak self] dict in
                guard let self = self else { return }
                if let data = try? JSONEncoder().encode(dict) {
                    self.ud.set(data, forKey: "savings.metals")
                }
            }
            .store(in: &cancellables)

        $fiat
            .sink { [weak self] dict in
                guard let self = self else { return }
                if let data = try? JSONEncoder().encode(dict) {
                    self.ud.set(data, forKey: "savings.fiat")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Fiat Helpers

    func binding(for currency: Currency) -> Binding<Double> {
        let code = currency.code.uppercased()
        return Binding<Double>(
            get: { self.fiat[code] ?? 0 },
            set: { self.fiat[code] = $0 }
        )
    }

    /// Какие коды валют стоит запросить у сервиса
    func fiatCodesToFetch() -> [String] {
        var codes = Set(fiat.keys.map { $0.uppercased() })
        codes.formUnion(["USD", "RUB"]) // обязательно
        return Array(codes)
    }

    func reset() {
        for k in CryptoAsset.allCases { cryptoHoldings[k] = 0 }
        for k in MetalAsset.allCases { metalGrams[k] = 0 }
        for k in fiat.keys { fiat[k] = 0 }
    }
}
