import Foundation

enum Cadence: String, Codable, CaseIterable { case monthly }

struct Income: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double
    var cadence: Cadence = .monthly
    var monthlyAmount: Double { amount }
}

struct Expense: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double
    var cadence: Cadence = .monthly
    var monthlyAmount: Double { amount }
}

struct Goal: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var targetAmount: Double
    var deadline: Date? = nil
}
