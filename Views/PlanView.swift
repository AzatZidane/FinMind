import SwiftUI

struct PlanView: View {
    @State private var profile: UserProfile = .sample
    private var plan: Plan { Plan(profile: profile) }

    var body: some View {
        NavigationStack {
            List {
                Section("Доходы") {
                    ForEach(profile.incomes) { i in row(name: i.name, amount: i.monthlyAmount) }
                }
                Section("Расходы") {
                    ForEach(profile.expenses) { e in row(name: e.name, amount: e.monthlyAmount) }
                }
                Section("Итог") {
                    row(name: "Доход", amount: plan.monthlyIncome)
                    row(name: "Расход", amount: plan.monthlySpending)
                    row(name: "Профицит", amount: plan.monthlyIncome - plan.monthlySpending, bold: true)
                }
            }
            .navigationTitle("План")
        }
    }

    @ViewBuilder
    private func row(name: String, amount: Double, bold: Bool = false) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(amount, format: .currency(code: profile.currencyCode))
                .fontWeight(bold ? .bold : .regular)
        }
    }
}

#Preview { NavigationStack { PlanView() } }
