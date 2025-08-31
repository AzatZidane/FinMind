import Foundation

enum MoneyFormat {
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()
}

extension Double {
    var asMoney: String {
        MoneyFormat.formatter.string(from: NSNumber(value: self))
        ?? String(format: "%.2f", self)
    }
}
