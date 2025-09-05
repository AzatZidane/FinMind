import SwiftUI

struct EditSavingsView: View {
    @ObservedObject var store: SavingsStore = .shared

    // какие валюты показывать в UI
    private var fiatList: [Currency] {
        let wanted = Set(["RUB","USD","EUR","CNY","TRY"])
        return Currency.supported.filter { wanted.contains($0.code.uppercased()) }
    }

    var body: some View {
        Form {
            Section("Фиат (сумма в валюте)") {
                ForEach(fiatList, id: \.code) { c in
                    HStack {
                        Text("\(c.code) \(c.symbol)")
                        Spacer()
                        DecimalField(
                            value: store.binding(for: c),
                            fractionDigits: 2,
                            width: 140
                        )
                    }
                }
            }

            Section("Криптовалюта (количество)") {
                ForEach(CryptoAsset.allCases) { asset in
                    HStack {
                        Text(asset.title)
                        Spacer()
                        DecimalField(
                            value: Binding(
                                get: { store.cryptoHoldings[asset] ?? 0 },
                                set: { store.cryptoHoldings[asset] = $0 }
                            ),
                            fractionDigits: 8,
                            width: 140
                        )
                    }
                }
            }

            Section("Драгоценные металлы (граммы)") {
                ForEach(MetalAsset.allCases) { m in
                    HStack {
                        Text(m.title)
                        Spacer()
                        DecimalField(
                            value: Binding(
                                get: { store.metalGrams[m] ?? 0 },
                                set: { store.metalGrams[m] = $0 }
                            ),
                            fractionDigits: 2,
                            width: 140
                        )
                    }
                }
            }

            Section {
                Button("Сбросить все значения", role: .destructive) { store.reset() }
            }
        }
        .navigationTitle("Сбережения")
    }
}

/// Компактное числовое поле, которое ОЧИЩАЕТСЯ при фокусе
private struct DecimalField: View {
    @Binding var value: Double
    let fractionDigits: Int
    let width: CGFloat

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: width)
            .focused($focused)
            .onAppear { text = format(value) }
            // очищаем при фокусе, форматируем при потере фокуса
            .onChange(of: focused) { isFocused in
                if isFocused {
                    text = ""                // сразу затираем
                } else {
                    // при выходе — фиксируем значение и форматируем
                    if let v = parse(text) { value = v }
                    text = format(value)
                }
            }
            // во время ввода обновляем связанное значение
            .onChange(of: text) { new in
                if focused, let v = parse(new) { value = v }
            }
    }

    private func format(_ v: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = " "
        nf.decimalSeparator = ","
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = fractionDigits
        return nf.string(from: NSNumber(value: v)) ?? "0"
    }

    private func parse(_ s: String) -> Double? {
        guard !s.isEmpty else { return 0 }
        let ds = s
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(ds)
    }
}
