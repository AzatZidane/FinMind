import Foundation

enum ReserveUnit: String, Codable { case fiat, coin, gram, troyOunce }

enum ReserveKind: Codable, Hashable {
    case fiat(Currency)
    case metal(Metal)
    case crypto(Crypto)

    enum CodingKeys: String, CodingKey { case t, code }
    enum KindType: String, Codable { case fiat, metal, crypto }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(KindType.self, forKey: .t) {
        case .fiat:  self = .fiat(Currency.byCode(try c.decode(String.self, forKey: .code)))
        case .metal: self = .metal(Metal(rawValue: try c.decode(String.self, forKey: .code))!)
        case .crypto:self = .crypto(Crypto(rawValue: try c.decode(String.self, forKey: .code))!)
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fiat(let cur):  try c.encode(KindType.fiat, forKey: .t);  try c.encode(cur.code, forKey: .code)
        case .metal(let m):   try c.encode(KindType.metal, forKey: .t); try c.encode(m.rawValue, forKey: .code)
        case .crypto(let k):  try c.encode(KindType.crypto, forKey: .t);try c.encode(k.rawValue, forKey: .code)
        }
    }
}

struct ReserveHolding: Identifiable, Codable {
    var id: UUID = UUID()
    var kind: ReserveKind
    var amount: Decimal
    var unit: ReserveUnit
}
