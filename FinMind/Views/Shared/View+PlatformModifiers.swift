import SwiftUI

// Безопасные модификаторы: на iOS работают, на macOS/старых SDK — игнорируются.
extension View {
    @ViewBuilder
    func decimalKeyboardIfAvailable() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberKeyboardIfAvailable() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
