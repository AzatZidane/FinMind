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
                        .onDelete { offsets in
                            app.debts.remove(atOffsets: offsets)
                        }
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

    @ViewBuilder
    private func row(_ d: Debt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(d.name) // через NameCompat -> .title
                Text("ежемесячный платёж")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(app.formatMoney(d.obligatoryMonthlyPayment, currency: d.currency))
                .font(.headline.monospacedDigit())
        }
    }
}

#Preview {
    DebtsListView().environmentObject(AppState())
}
