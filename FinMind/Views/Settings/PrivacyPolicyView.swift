import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Политика конфиденциальности FinMind")
                    .font(.title2)
                    .bold()

                Group {
                    Text("Приложение **FinMind** собирает и обрабатывает только данные, необходимые для работы:")
                    Text("— доходы, расходы, цели и долги, которые пользователь вводит вручную;")
                    Text("— параметры профиля (аватар, никнейм, настройки темы).")
                }

                Text("Данные хранятся локально на устройстве пользователя и могут синхронизироваться через iCloud (если включено).")

                Text("Для работы советника запросы передаются на сервер-прокси FinMind, который использует технологию OpenAI. Персональные данные (ФИО, контакты и т.п.) не собираются и не передаются.")

                Text("Пользователь может в любой момент удалить все данные в настройках приложения.")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Контакты разработчика:")
                        .bold()
                    Text("Email: ismagilovazat48@gmail.com")
                }
            }
            .padding()
        }
        .navigationTitle("Политика")
        .navigationBarTitleDisplayMode(.inline)
    }
}
