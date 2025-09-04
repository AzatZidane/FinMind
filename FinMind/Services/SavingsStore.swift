import Foundation
import Combine

/// Поддерживаемые криптоактивы
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
    /// ID в CoinGecko
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

/// Драгоценные металлы (количество храним в граммах)
enum MetalAsset: String, CaseIterable, Identifiable, Codable {
    case xau, xag, xpt, xpd
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .xau: return "XAU"
        case .xag: return "XAG"
        case .xpt: return "XPT"
        case .xpd: return "XPD"
        }
    }
    var title: String {
        switch self {
        case .xau: return "Золото (XAU)"
        case .xag: return "Серебро (XAG)"
        case .xpt: return "Платина (XPT)"
        case .xpd: return "Палладий (XPD)"
        }
    }
}

final class SavingsStore: ObservableObject {
    static let shared = SavingsStore()

    @Published var cryptoHoldings: [CryptoAsset: Double]   // количество монет
    @Published var metalGrams: [MetalAsset: Double]        // граммы

    private var cancellables = Set<AnyCancellable>()
    private let ud = UserDefaults.standard

    private init() {
        // загрузка
        if let data = ud.data(forKey: "savings.crypto"),
           let decoded = try? JSONDecoder().decode([CryptoAsset: Double].self, from: data) {
            cryptoHoldings = decoded
        } else {
            cryptoHoldings = Dictionary(uniqueKeysWithValues: CryptoAsset.allCases.map { ($0, 0) })
        }
        if let data = ud.data(forKey: "savings.metals"),
           let decoded = try? JSONDecoder().decode([MetalAsset: Double].self, from: data) {
            metalGrams = decoded
        } else {
            metalGrams = Dictionary(uniqueKeysWithValues: MetalAsset.allCases.map { ($0, 0) })
        }

        // автосохранение при изменении
        $cryptoHoldings
            .sink { [weak self] dict in
                guard let self = self, let data = try? JSONEncoder().encode(dict) else { return }
                self.ud.set(data, forKey: "savings.crypto")
            }
            .store(in: &cancellables)

        $metalGrams
            .sink { [weak self] dict in
                guard let self = self, let data = try? JSONEncoder().encode(dict) else { return }
                self.ud.set(data, forKey: "savings.metals")
            }
            .store(in: &cancellables)
    }

    // Утиль
    func reset() {
        for k in CryptoAsset.allCases { cryptoHoldings[k] = 0 }
        for k in MetalAsset.allCases { metalGrams[k] = 0 }
    }
}
