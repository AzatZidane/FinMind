import SwiftUI

struct AdvisorView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Быстрые действия") {
                    NavigationLink("Как сократить расходы на 10%") { Text("Советы и приёмы…") }
                    NavigationLink("Построить бюджет на месяц") { Text("Мастер‑план на месяц…") }
                    NavigationLink("Оптимизировать кредиты") { Text("Сценарии погашения…") }
                }

                Section("Полезные материалы") {
                    Link("Финансовая подушка: с чего начать", destination: URL(string: "https://example.com")!)
                    Link("Как копить на цель", destination: URL(string: "https://example.com")!)
                }
            }
            .navigationTitle(UIStrings.tab3)
        }
    }
}

#Preview { AdvisorView() }
