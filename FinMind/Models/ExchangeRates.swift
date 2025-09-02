import Foundation

enum Metal: String, Codable, CaseIterable, Hashable { case XAU, XAG } // золото, серебро
enum Crypto: String, Codable, CaseIterable, Hashable { case BTC, ETH, USDT, USDC }

struct ExchangeRates: Codable {
    // Сколько USD стоит 1 единица валюты
    var usdPerUnitFiat: [String: Decimal] = [
        "USD": 1, "EUR": 1.10, "RUB": 0.011, "CNY": 0.14, "KZT": 0.0022, "TRY": 0.030
    ]
    // Цена металлов (USD за 1 тр. унцию)
    var usdPerTroyOunce: [Metal: Decimal] = [ .XAU: 2000, .XAG: 25 ]
    // Цена монет в USD
    var usdPerCoin: [Crypto: Decimal] = [ .BTC: 60000, .ETH: 2500, .USDT: 1, .USDC: 1 ]

    var updatedAt: Date? = Date()

    func convert(amount: Decimal, from: Currency, to: Currency) -> Decimal? {
        guard let fromUSD = usdPerUnitFiat[from.code], let toUSD = usdPerUnitFiat[to.code], toUSD != 0 else { return nil }
        return (amount * fromUSD) / toUSD
    }
    func metalTo(currency: Currency, metal: Metal, amountInTroyOunces: Decimal) -> Decimal? {
        guard let priceUSD = usdPerTroyOunce[metal], let toUSD = usdPerUnitFiat[currency.code], toUSD != 0 else { return nil }
        return (amountInTroyOunces * priceUSD) / toUSD
    }
    func cryptoTo(currency: Currency, crypto: Crypto, amount: Decimal) -> Decimal? {
        guard let priceUSD = usdPerCoin[crypto], let toUSD = usdPerUnitFiat[currency.code], toUSD != 0 else { return nil }
        return (amount * priceUSD) / toUSD
    }
}
