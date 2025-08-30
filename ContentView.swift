import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            BudgetView()
                .tabItem {
                    Label("Данные", systemImage: "list.bullet.rectangle")
                }
            
            // Заглушка для "План" (будет подключён FinanceEngine позже)
            PlanViewPlaceholder()
                .tabItem {
                    Label("План", systemImage: "chart.pie.fill")
                }
            
            AdvisorViewPlaceholder()
                .tabItem {
                    Label("Советник", systemImage: "sparkles")
                }
            
            SettingsViewPlaceholder()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
        }
    }
}

// MARK: - Placeholders (минимальные заглушки для сборки)
struct PlanViewPlaceholder: View {
    var body: some View {
        NavigationStack {
            Text("Здесь будет аналитика и СДП")
                .foregroundStyle(.secondary)
                .navigationTitle("План")
        }
    }
}

struct AdvisorViewPlaceholder: View {
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
                        .onChange(of: question, initial: false) { oldValue, newValue in
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

struct SettingsViewPlaceholder: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Настройки профиля, темы, обратная связь и др.")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Настройки")
        }
    }
}

#Preview {
    ContentView()
}
