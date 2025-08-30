import SwiftUI

struct SettingsView: View {
    @AppStorage("currencyCode") private var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("firstWeekday") private var firstWeekday: Int = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Формат") {
                    TextField("Валюта", text: $currencyCode)
                    Picker("Первый день недели", selection: $firstWeekday) {
                        Text("Воскресенье").tag(1)
                        Text("Понедельник").tag(2)
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}

#Preview { SettingsView() }
