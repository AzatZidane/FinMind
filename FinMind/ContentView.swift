import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Вкладка 1 — «Данные» (экран данных/бюджета)
            // Используем существующий экран обзора как «Данные».
            BudgetView()
                .tabItem {
                    Label("Данные", systemImage: "list.bullet.rectangle")
                }

            
            // Вкладка 2 — «План» (аналитика/СДП)
            PlanView()
                .tabItem {
                    Label("План", systemImage: "chart.pie.fill")
                }
            
            // Вкладка 3 — «Советник» (ИИ)
            AdvisorView()
                .tabItem {
                    Label("Советник", systemImage: "sparkles")
                }
            
            // Вкладка 4 — «Настройки»
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
        }
    }
}

// Простейшая заглушка экрана «Советник»
// Добавлена здесь, чтобы сборка прошла даже если отдельного файла AdvisorView.swift ещё нет.
// Позже можно вынести в отдельный файл и подключить ChatService.
struct AdvisorView: View {
    @State private var question: String = ""
    private let limit = 100
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Короткие, практичные советы по личным финансам.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    TextField("Ваш вопрос (до 100 символов)…", text: $question)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: question) { newValue in
                            if newValue.count > limit {
                                question = String(newValue.prefix(limit))
                            }
                        }
                    Text("\(question.count)/\(limit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    // TODO: подключить ChatService / Cloudflare Worker прокси
                } label: {
                    Text("Отправить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Советник")
        }
    }
}

#Preview {
    ContentView()
}
