import SwiftUI
import UIKit

/// Поле ввода для целых сумм с пробельной группировкой.
/// - убирает ведущий "0" при фокусе
/// - форматирует число как `1 234 567` во время ввода
struct GroupedIntField: View {
    @Binding var value: Int
    var placeholder: String = "0"
    var clearZeroOnFocus: Bool = true

    @State private var text: String = ""
    @FocusState private var focused: Bool
    @State private var isFormatting = false

    private static let nf: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()

    var body: some View {
        UIKitTextField(
            text: $text,
            onEditingChanged: { began in
                if began, clearZeroOnFocus, value == 0 {
                    text = "" // убираем "0" на старте
                }
            }
        )
        .keyboardType(.numberPad)
        .focused($focused)
        .onAppear {
            text = Self.nf.string(from: NSNumber(value: value)) ?? ""
        }
        .onChange(of: value) { new in
            guard !isFormatting else { return }
            text = Self.nf.string(from: NSNumber(value: new)) ?? ""
        }
        .onChange(of: text) { newText in
            guard !isFormatting else { return }
            isFormatting = true
            // оставляем только цифры
            let digits = newText.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
            let raw = String(String.UnicodeScalarView(digits))
            let intVal = Int(raw) ?? 0
            value = intVal
            text = raw.isEmpty ? "" : (Self.nf.string(from: NSNumber(value: intVal)) ?? raw)
            isFormatting = false
        }
        .toolbar { // кнопка «Готово» для numberPad
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { focused = false }
            }
        }
        .overlay(
            Group {
                if text.isEmpty && !focused {
                    Text(placeholder).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

// MARK: - UIKit обёртка
private struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String
    var onEditingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.textAlignment = .right
        tf.keyboardType = .numberPad
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingDidBegin), for: .editingDidBegin)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        let parent: UIKitTextField
        init(_ p: UIKitTextField) { self.parent = p }

        @objc func editingChanged(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }
        @objc func editingDidBegin(_ tf: UITextField) {
            parent.onEditingChanged(true)
        }
    }
}
