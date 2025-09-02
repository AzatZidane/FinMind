import Foundation

struct Currency: Codable, Hashable, Identifiable {
    let code: String
    let symbol: String
    let fractionDigits: Int
    var id: String { code }

    static let rub = Currency(code: "RUB", symbol: "₽", fractionDigits: 2)
    static let usd = Currency(code: "USD", symbol: "$", fractionDigits: 2)
    static let eur = Currency(code: "EUR", symbol: "€", fractionDigits: 2)
    static let cny = Currency(code: "CNY", symbol: "¥", fractionDigits: 2)
    static let kzt = Currency(code: "KZT", symbol: "₸", fractionDigits: 2)
    static let tryy = Currency(code: "TRY", symbol: "₺", fractionDigits: 2)

    static let supported: [Currency] = [.rub, .usd, .eur, .cny, .kzt, .tryy]

    static func byCode(_ code: String) -> Currency {
        supported.first { $0.code == code } ?? .rub
    }
}
