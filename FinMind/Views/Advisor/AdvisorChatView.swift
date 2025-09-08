import SwiftUI

struct AdvisorChatView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var vm = ChatVM()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    // Лента сообщений
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(vm.messages.enumerated()), id: \.offset) { idx, msg in
                                bubble(for: msg).id(idx)
                            }
                            if vm.isStreaming { ProgressView().padding(.leading, 8) }
                        }
                        .padding(12)
                    }
                    // Скрытие клавиатуры жестом прокрутки (iOS 16+) и тапом
                    .background(Color.clear.contentShape(Rectangle())
                        .onTapGesture { isInputFocused = false })
                    .applyScrollDismissKeyboardIfAvailable()

                    // Автоскролл к последнему сообщению
                    .onChangeCompat(of: vm.messages.count) {
                        withAnimation { proxy.scrollTo(vm.messages.count - 1, anchor: .bottom) }
                    }
                }

                Divider()

                // Панель ввода
                HStack(spacing: 8) {
                    TextField("Спросите про бюджет, долги, подушку…", text: $vm.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit { Task { await vm.send(app: app); isInputFocused = false } }

                    // Кнопка "Скрыть клавиатуру" рядом с инпутом
                    if isInputFocused {
                        Button {
                            isInputFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        Task { await vm.send(app: app) }
                        isInputFocused = false
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStreaming)
                }
                .padding(12)
            }
            .navigationTitle("Чат с советником")
            .toolbar {
                // Кнопка "Скрыть" на панели клавиатуры
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        isInputFocused = false
                    } label: {
                        Label("Скрыть", systemImage: "keyboard.chevron.compact.down")
                    }
                }

                // Меню действий
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            vm.clearChat()
                        } label: {
                            Label("Новый чат", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(for m: ChatMessage) -> some View {
        HStack {
            if m.role == .assistant { Spacer() }
            Text(m.content)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(m.role == .assistant ? Color.secondary.opacity(0.15)
                                                   : Color.accentColor.opacity(0.15))
                )
            if m.role == .user { Spacer() }
        }
    }
}

// MARK: - ViewModel (как было)

final class ChatVM: ObservableObject {
    @Published var messages: [ChatMessage]
    @Published var input = ""
    @Published var isStreaming = false

    private let service = OpenAIChatService.shared
    private let storage = ChatStorage.shared

    init() {
        self.messages = storage.load()
    }

    private func systemMessage(app: AppState) -> ChatMessage {
        var text = "Вы — финансовый помощник. Давайте рекомендации осторожно и без категоричных обещаний.\n"
        text += "Вот текущие данные пользователя:\n"

        if !app.incomes.isEmpty {
            text += "\nДоходы:"
            for i in app.incomes { text += "\n- \(i.name): \(i.amount)" }
        }
        if !app.expenses.isEmpty {
            text += "\nРасходы:"
            for e in app.expenses { text += "\n- \(e.name): \(e.amount)" }
        }
        if !app.debts.isEmpty {
            text += "\nДолги:"
            for d in app.debts { text += "\n- \(d.name)" }
        }
        if !app.goals.isEmpty {
            text += "\nЦели:"
            for g in app.goals { text += "\n- \(g.name): \(g.targetAmount)" }
        }

        return .init(role: .system, content: text)
    }

    @MainActor
    func send(app: AppState) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""

        let userMsg = ChatMessage(role: .user, content: text)

        // Контекст = свежий system (с данными) + история + новый вопрос
        let context: [ChatMessage] = [systemMessage(app: app)] + messages + [userMsg]

        messages.append(userMsg)
        isStreaming = true
        messages.append(.init(role: .assistant, content: ""))

        do {
            try await service.stream(messages: context, onDelta: { [weak self] token in
                Task { @MainActor in
                    guard let self = self else { return }
                    if var last = self.messages.popLast() {
                        last = .init(role: .assistant, content: last.content + token)
                        self.messages.append(last)
                    }
                }
            }, onFinish: { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isStreaming = false
                    self.storage.save(self.messages)
                }
            })
        } catch {
            await MainActor.run {
                self.isStreaming = false
                self.messages.append(.init(role: .assistant, content: "Ошибка: \(error.localizedDescription)"))
                self.storage.save(self.messages)
            }
        }
    }

    @MainActor
    func clearChat() {
        messages.removeAll()
        storage.clear()
    }
}

// MARK: - Утилиты для совместимости iOS 16/17

private extension View {
    /// iOS 16+: скрывает клавиатуру при прокрутке; на iOS 15 просто возвращает self
    @ViewBuilder
    func applyScrollDismissKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }

    /// Единая onChange-обёртка: iOS17 — новая сигнатура, iOS16 — старая
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, _ in action() }
        } else {
            self.onChange(of: value) { _ in action() }
        }
    }
}
