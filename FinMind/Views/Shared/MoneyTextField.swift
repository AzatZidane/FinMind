import SwiftUI
import UIKit

struct MoneyTextField: UIViewRepresentable {
    @Binding var value: Decimal?
    var fractionDigits: Int = 2
    var groupingSeparator: String = "."
    var decimalSeparator: String = ","
    var placeholder: String? = nil

    var font: UIFont = .preferredFont(forTextStyle: .title3)
    var textColor: UIColor = .label
    var separatorColor: UIColor = UIColor.label.withAlphaComponent(0.3)

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .decimalPad
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
            context.coordinator.setFormattedText(formatted, on: uiView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

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

        func rebuildFormatter() {
            numberFormatter.groupingSeparator = groupingSeparator
            numberFormatter.decimalSeparator = decimalSeparator
            numberFormatter.minimumFractionDigits = fractionDigits
            numberFormatter.maximumFractionDigits = fractionDigits
        }

        func format(_ value: Decimal?) -> String {
            rebuildFormatter()
            guard let value else { return "" }
            return numberFormatter.string(from: value as NSDecimalNumber) ?? ""
        }

        func parse(_ string: String) -> Decimal? {
            rebuildFormatter()
            let cleaned = string
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: groupingSeparator, with: "")
                .replacingOccurrences(of: decimalSeparator, with: ".")
            return Decimal(string: cleaned)
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {

            let allowed = CharacterSet(charactersIn: "0123456789\(decimalSeparator)")
            if string.rangeOfCharacter(from: allowed.inverted) != nil { return false }

            let current = textField.text ?? ""
            guard let textRange = Range(range, in: current) else { return false }
            let newRaw = current.replacingCharacters(in: textRange, with: string)

            let newValue = parse(newRaw)
            parent.value = newValue

            let formatted = format(newValue)
            setFormattedText(formatted, on: textField, replacing: range, replacement: string, original: current)
            return false
        }

        @objc func editingChanged(_ textField: UITextField) {
            parent.value = parse(textField.text ?? "")
            applyAttributes(on: textField)
        }

        func setFormattedText(_ formatted: String,
                              on textField: UITextField,
                              replacing range: NSRange? = nil,
                              replacement: String? = nil,
                              original: String? = nil) {

            let wasSel = textField.selectedTextRange
            let caretOffsetFromEnd: Int
            if let wasSel = wasSel {
                let start = textField.offset(from: textField.endOfDocument, to: wasSel.start)
                caretOffsetFromEnd = -start
            } else { caretOffsetFromEnd = 0 }

            textField.attributedText = attributed(formatted)
            applyAttributes(on: textField)

            let newPos = textField.position(from: textField.endOfDocument,
                                            offset: -max(0, caretOffsetFromEnd)) ?? textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: newPos, to: newPos)
        }

        func attributed(_ s: String) -> NSAttributedString {
            let attr = NSMutableAttributedString(string: s, attributes: [
                .foregroundColor: textColor, .font: font
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
