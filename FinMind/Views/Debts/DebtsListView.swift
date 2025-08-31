import SwiftUI

struct DebtsListView: View {
    @EnvironmentObject var app: AppState
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                if app.debts.isEmpty {
                    Section { Text("Долгов пока нет").foregroundStyle(.secondary) }
                } else {
                    Section("ДОЛГИ") {
                        ForEach(Array(app.debts.enumerated()), id: \.offset) { _, debt in
                            row(debt)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Долги")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddDebtView().environmentObject(app)
            }
        }
    }

    // Строка списка
    @ViewBuilder
    private func row(_ d: Debt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(d.name)
                Text(subtitle(for: d))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let amt = amount(for: d) {
                Text("\(amt, specifier: "%.2f")")
                    .font(.headline.monospacedDigit())
            }
        }
    }

    // Доп. подпись и сумма справа
    private func subtitle(for d: Debt) -> String {
        switch d.input {
        case .monthlyPayment(_, let isMinimum):
            return isMinimum ? "ежемесячный (минимум)" : "ежемесячный"
        case .loan(_, _, let termMonths, let grace, _):
            if let g = grace { return "кредит • \(termMonths) мес • грейс \(g) мес" }
            return "кредит • \(termMonths) мес"
        }
    }

    private func amount(for d: Debt) -> Double? {
        switch d.input {
        case .monthlyPayment(let amount, _):
            return amount
        case .loan(let principal, _, _, _, let minPayment):
            return minPayment ?? principal
        }
    }

    private func delete(at offsets: IndexSet) {
        app.debts.remove(atOffsets: offsets)
    }
}

#Preview {
    DebtsListView().environmentObject(AppState())
}
