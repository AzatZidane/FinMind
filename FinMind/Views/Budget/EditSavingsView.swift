import SwiftUI

struct EditSavingsView: View {
    @ObservedObject var store: SavingsStore = .shared

    var body: some View {
        Form {
            Section("Криптовалюта (количество)") {
                ForEach(CryptoAsset.allCases) { asset in
                    HStack {
                        Text(asset.title)
                        Spacer()
                        DecimalField(value: Binding(
                            get: { store.cryptoHoldings[asset] ?? 0 },
                            set: { store.cryptoHoldings[asset] = $0 }
                        ), fractionDigits: 8, width: 140)
                    }
                }
            }

            Section("Драгоценные металлы (граммы)") {
                ForEach(MetalAsset.allCases) { m in
                    HStack {
                        Text(m.title)
                        Spacer()
                        DecimalField(value: Binding(
                            get: { store.metalGrams[m] ?? 0 },
                            set: { store.metalGrams[m] = $0 }
                        ), fractionDigits: 2, width: 120)
                    }
                }
            }

            Section {
                Button("Сбросить значения", role: .destructive) { store.reset() }
            }
        }
        .navigationTitle("Сбережения")
    }
}

/// Компактное числовое поле (без валютных символов)
private struct DecimalField: View {
    @Binding var value: Double
    let fractionDigits: Int
    let width: CGFloat

    @State private var text: String = ""

    var body: some View {
        TextField("0", text: Binding(
            get: { text.isEmpty ? format(value) : text },
            set: { new in
                text = new
                value = parse(new) ?? value
            }
        ))
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(width: width)
        .onAppear { text = format(value) }
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
        let ds = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(ds)
    }
}
