import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Профиль")) {
                    // твои элементы профиля
                    Text("Имя профиля (заглушка)")
                }

                Section(header: Text("Параметры")) {
                    // твои параметры приложения
                    Toggle("Автосохранение (всегда включено)", isOn: .constant(true))
                        .disabled(true)
                }

                // НОВЫЙ раздел
                Section(header: Text("Данные")) {
                    NavigationLink {
                        BackupView().environmentObject(app)
                    } label: {
                        Label("Резервная копия", systemImage: "externaldrive.badge.icloud")
                    }
                }
            }
            .navigationTitle(UIStrings.tab4) // если у тебя другой заголовок — поставь свой
        }
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
