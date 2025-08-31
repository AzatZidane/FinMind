import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section("Профиль") {
                    NavigationLink("Аккаунт") { Text("Данные профиля…") }
                }

                Section("Данные") {
                    HStack { Text("Доходов");  Spacer(); Text("\(app.incomes.count)") }
                    HStack { Text("Расходов"); Spacer(); Text("\(app.expenses.count)") }
                    HStack { Text("Долгов");   Spacer(); Text("\(app.debts.count)") }
                    HStack { Text("Целей");    Spacer(); Text("\(app.goals.count)") }
                }

                Section("Опасная зона") {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text("Сбросить все данные")
                    }
                }
            }
            .navigationTitle(UIStrings.tab4)
            .alert("Удалить все данные?", isPresented: $confirmReset) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить", role: .destructive) {
                    app.incomes.removeAll()
                    app.expenses.removeAll()
                    app.debts.removeAll()
                    app.goals.removeAll()
                    app.dailyEntries.removeAll()
                }
            } message: {
                Text("Действие необратимо.")
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
