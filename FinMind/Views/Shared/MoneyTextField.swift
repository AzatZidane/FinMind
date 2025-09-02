import SwiftUI
import UIKit

/// Поле ввода денег с живым форматированием:
/// - Работает и с копейками (fractionDigits > 0), и без (fractionDigits = 0).
/// - Разделители тысяч — полупрозрачные.
/// - Курсор ставится в нужное место автоматически.
struct MoneyTextField: UIViewRepresentable {
    @Binding var value: Decimal?
    var fractionDigits: Int = 2
    var groupingSeparator: String = "."
    var decimalSeparator: String = ","
    var placeholder: String? = nil

    var font: UIFont = .preferredFont(forTextStyle: .title3)
    var textColor: UIColor = .label
    var separatorColor: UIColor = UIColor.label.withAlphaComponent(0.3) // полупрозрачные точки

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .numberPad  // вводим только цифры; точку/запятую набивать не нужно
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        tf.font = font
        tf.textColor = textColor
        tf.placeholder = placeholder
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.fractionDigits = fractionDigits
        context.coordinator.groupingSeparator = groupingSeparator
        context.coordinator.decimalSeparator = decimalSeparator
        context.coordinator.separatorColor = separatorColor
        context.coordinator.textColor = textColor
        context.coordinator.font = font

        let formatted = context.coordinator.format(value)
        if uiView.text != formatted {
            context.coordinator.setFormattedText(formatted,
                                                 on: uiView,
                                                 placeCursorBeforeDecimal: (fractionDigits > 0))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MoneyTextField
        var fractionDigits: Int
        var groupingSeparator: String
        var decimalSeparator: String
        var separatorColor: UIColor
        var textColor: UIColor
        var font: UIFont

        init(_ parent: MoneyTextField) {
            self.parent = parent
            self.fractionDigits = parent.fractionDigits
            self.groupingSeparator = parent.groupingSeparator
            self.decimalSeparator = parent.decimalSeparator
            self.separatorColor = parent.separatorColor
            self.textColor = parent.textColor
            self.font = parent.font
        }

        private lazy var numberFormatter: NumberFormatter = {
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.usesGroupingSeparator = true
            return nf
        }()

        private func rebuildFormatter() {
            numberFormatter.groupingSeparator = groupingSeparator
            numberFormatter.decimalSeparator = decimalSeparator
            numberFormatter.minimumFractionDigits = max(0, fractionDigits)
            numberFormatter.maximumFractionDigits = max(0, fractionDigits)
        }

        // MARK: Public helpers

        func format(_ value: Decimal?) -> String {
            rebuildFormatter()
            guard let value else { return "" }
            return numberFormatter.string(from: value as NSDecimalNumber) ?? ""
        }

        /// Возвращает все цифры из строки, учитывая режим:
        /// - если fractionDigits == 0 — просто убираем разделители и не глядим на запятую;
        /// - если > 0 — берем только целую часть (цифры до запятой).
        private func integerDigits(in s: String) -> String {
            if fractionDigits == 0 {
                // Удаляем все нецифры
                return s.filter { $0.isNumber }
            } else {
                let parts = s.components(separatedBy: decimalSeparator)
                let integerPart = parts.first ?? s
                let cleaned = integerPart.replacingOccurrences(of: groupingSeparator, with: "")
                return cleaned.filter { $0.isNumber }
            }
        }

        private func text(fromIntegerDigits digits: String) -> String {
            if digits.isEmpty { return "" }
            let dec = Decimal(string: digits) ?? 0
            return format(dec)
        }

        // MARK: UITextFieldDelegate

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {

            // Разрешаем только цифры и backspace
            if !string.isEmpty,
               string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
                return false
            }

            let currentText = textField.text ?? ""
            var digits = integerDigits(in: currentText)

            if string.isEmpty {
                // backspace — удаляем ПОСЛЕДНЮЮ цифру целой части
                if !digits.isEmpty { digits.removeLast() }
            } else {
                // обычный ввод — добавляем цифры в конец целой части
                digits.append(contentsOf: string.filter { $0.isNumber })
            }

            if digits.isEmpty {
                parent.value = nil
                setFormattedText("", on: textField, placeCursorBeforeDecimal: false)
                return false
            }

            let newValue = Decimal(string: digits) ?? 0
            parent.value = newValue

            let formatted = text(fromIntegerDigits: digits)
            setFormattedText(formatted,
                             on: textField,
                             placeCursorBeforeDecimal: (fractionDigits > 0))

            return false // сами обновили текст
        }

        @objc func editingChanged(_ textField: UITextField) {
            // синхронизация на случай посторонних изменений
            let digits = integerDigits(in: textField.text ?? "")
            let newValue = digits.isEmpty ? nil : (Decimal(string: digits) ?? 0)
            parent.value = newValue
            applyAttributes(on: textField)
        }

        // MARK: Cursor & attributes

        func setFormattedText(_ formatted: String,
                              on textField: UITextField,
                              placeCursorBeforeDecimal: Bool) {
            textField.attributedText = attributed(formatted)
            applyAttributes(on: textField)

            if placeCursorBeforeDecimal,
               let t = textField.text {
                let ns = t as NSString
                let sepRange = ns.range(of: decimalSeparator)
                if sepRange.location != NSNotFound,
                   let startPos = textField.position(from: textField.beginningOfDocument, offset: sepRange.location),
                   let caretRange = textField.textRange(from: startPos, to: startPos) {
                    textField.selectedTextRange = caretRange
                    return
                }
            }
            // иначе — в конец
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
        }

        func attributed(_ s: String) -> NSAttributedString {
            let attr = NSMutableAttributedString(string: s, attributes: [
                .foregroundColor: textColor,
                .font: font
            ])
            let ns = s as NSString
            var searchRange = NSRange(location: 0, length: ns.length)
            while true {
                let r = ns.range(of: groupingSeparator, options: [], range: searchRange)
                if r.location == NSNotFound { break }
                attr.addAttributes([.foregroundColor: separatorColor], range: r)
                let nextLoc = r.location + r.length
                searchRange = NSRange(location: nextLoc, length: ns.length - nextLoc)
            }
            return attr
        }

        func applyAttributes(on textField: UITextField) {
            if let t = textField.text { textField.attributedText = attributed(t) }
        }
    }
}
