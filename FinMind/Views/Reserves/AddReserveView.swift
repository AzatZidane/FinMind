import SwiftUI

struct AddReserveView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var kindIdx = 0 // 0=fiat,1=metal,2=crypto
    @State private var selectedCurrency: Currency = .usd
    @State private var selectedMetal: Metal = .XAU
    @State private var selectedCrypto: Crypto = .BTC
    @State private var unit: ReserveUnit = .fiat
    @State private var amount: Decimal? = nil

    var body: some View {
        NavigationStack {
            Form {
                Picker("Тип", selection: $kindIdx) {
                    Text("Валюта").tag(0)
                    Text("Металл").tag(1)
                    Text("Крипто").tag(2)
                }
                .onChange(of: kindIdx) { _, newValue in
                    switch newValue { case 0: unit = .fiat; case 1: unit = .gram; case 2: unit = .coin; default: break }
                }

                if kindIdx == 0 {
                    Picker("Валюта", selection: $selectedCurrency) {
                        ForEach(Currency.supported) { Text($0.code).tag($0) }
                    }
                } else if kindIdx == 1 {
                    Picker("Металл", selection: $selectedMetal) {
                        ForEach(Metal.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Единицы", selection: $unit) {
                        Text("Граммы").tag(ReserveUnit.gram)
                        Text("Тр. унции").tag(ReserveUnit.troyOunce)
                    }
                } else {
                    Picker("Криптовалюта", selection: $selectedCrypto) {
                        ForEach(Crypto.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                MoneyTextField(value: $amount,
                               fractionDigits: (kindIdx == 2 ? 8 : (kindIdx == 0 ? selectedCurrency.fractionDigits : 3)),
                               groupingSeparator: ".",
                               decimalSeparator: ",",
                               placeholder: "0,00")
            }
            .navigationTitle("Добавить актив")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let amt = amount ?? 0
                        let holding: ReserveHolding = {
                            switch kindIdx {
                            case 0: return ReserveHolding(kind: .fiat(selectedCurrency), amount: amt, unit: .fiat)
                            case 1: return ReserveHolding(kind: .metal(selectedMetal), amount: amt, unit: unit)
                            default: return ReserveHolding(kind: .crypto(selectedCrypto), amount: amt, unit: .coin)
                            }
                        }()
                        appState.addReserve(holding); dismiss()
                    }.disabled((amount ?? 0) == 0)
                }
            }
        }
    }
}
