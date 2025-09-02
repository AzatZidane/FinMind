import SwiftUI

struct ReservesListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(appState.reserves) { r in
                    HStack {
                        Text(title(for: r))
                        Spacer()
                        let val = NSDecimalNumber(decimal: appState.reserveValueInBase(r)).doubleValue
                        Text(appState.formatMoney(val, currency: appState.baseCurrency))
                    }
                    .swipeActions {
                        Button(role: .destructive) { appState.removeReserve(r) } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                let total = NSDecimalNumber(decimal: appState.totalReservesInBase()).doubleValue
                Text("Итого: \(appState.formatMoney(total, currency: appState.baseCurrency))")
            }
        }
        .navigationTitle("Запас")
        .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showAdd) { AddReserveView().environmentObject(appState) }
    }

    func title(for r: ReserveHolding) -> String {
        switch r.kind {
        case .fiat(let c):   return "\(c.code) \(c.symbol) — \(r.amount)"
        case .crypto(let k): return "\(k.rawValue) — \(r.amount)"
        case .metal(let m):  return "\(m.rawValue) — \(r.amount) \(r.unit == .gram ? "г" : "oz")"
        }
    }
}
