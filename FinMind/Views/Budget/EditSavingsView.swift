import SwiftUI
import UIKit

struct EditSavingsView: View {
    @ObservedObject var store: SavingsStore = .shared

    private var fiatList: [Currency] {
        let wanted = Set(["RUB","USD","EUR","CNY","TRY"])
        return Currency.supported.filter { wanted.contains($0.code.uppercased()) }
    }

    var body: some View {
        Form {
            Section("ФИАТ (СУММА В ВАЛЮТЕ)") {
                ForEach(fiatList, id: \.code) { c in
                    HStack {
                        Text("\(c.code) \(c.symbol)")
                        Spacer()
                        DecimalFieldUIKit(
                            value: store.binding(for: c),
                            fractionDigits: 2
                        )
                        .frame(width: 140)
                    }
                }
            }

            Section("КРИПТОВАЛЮТА (КОЛИЧЕСТВО)") {
                ForEach(CryptoAsset.allCases) { asset in
                    HStack {
                        Text(asset.title)
                        Spacer()
                        DecimalFieldUIKit(
                            value: Binding(
                                get: { store.cryptoHoldings[asset] ?? 0 },
                                set: { store.cryptoHoldings[asset] = $0 }
                            ),
                            fractionDigits: 8
                        )
                        .frame(width: 140)
                    }
                }
            }

            Section {
                Button("Сбросить все значения", role: .destructive) { store.reset() }
            }
        }
        .navigationTitle("Сбережения")
        .scrollDismissesKeyboard(.interactively)
        .background(Color.clear.contentShape(Rectangle()).onTapGesture { hideKeyboard() })
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Поле ввода на UIKit: курсор в конец, «Готово», формат при потере фокуса
private struct DecimalFieldUIKit: UIViewRepresentable {
    @Binding var value: Double
    let fractionDigits: Int

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .decimalPad
        tf.textAlignment = .right
        tf.adjustsFontSizeToFitWidth = true
        tf.minimumFontSize = 12
        tf.delegate = context.coordinator
        tf.text = context.coordinator.format(value)

        let tb = UIToolbar()
        tb.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Готово", style: .done,
                                   target: context.coordinator,
                                   action: #selector(Coordinator.doneTapped))
        tb.items = [flex, done]
        tf.inputAccessoryView = tb

        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if !tf.isFirstResponder {
            let formatted = context.coordinator.format(value)
            if tf.text != formatted {
                tf.text = formatted
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, fractionDigits: fractionDigits)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var value: Binding<Double>
        let fractionDigits: Int

        init(value: Binding<Double>, fractionDigits: Int) {
            self.value = value
            self.fractionDigits = fractionDigits
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                let end = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            textField.text = format(value.wrappedValue)
        }

        @objc func editingChanged(_ textField: UITextField) {
            let s = textField.text ?? ""
            if let v = parse(s) { value.wrappedValue = v }
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool { true }

        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }

        private func nf() -> NumberFormatter {
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.groupingSeparator = " "
            nf.decimalSeparator = ","
            nf.minimumFractionDigits = 0
            nf.maximumFractionDigits = fractionDigits
            return nf
        }

        func format(_ v: Double) -> String {
            let vv = v.isFinite ? v : 0
            return nf().string(from: NSNumber(value: vv)) ?? "0"
        }

        func parse(_ s: String) -> Double? {
            let cleaned = s
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            if cleaned.isEmpty { return 0 }
            return Double(cleaned)
        }
    }
}
