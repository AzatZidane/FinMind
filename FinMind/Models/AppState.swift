//
//  AppState.swift
//  FinMind
//

import Foundation
import Combine
import SwiftUI

/// Глобальное состояние приложения.
/// Хранит массивы сущностей и предоставляет методы добавления/удаления.
/// Также автоматически сохраняет состояние при изменениях.
final class AppState: ObservableObject, Codable {

    // MARK: - Публичные @Published-данные

    @Published var incomes: [Income] = []
    @Published var expenses: [Expense] = []
    @Published var debts: [Debt] = []
    @Published var goals: [Goal] = []
    @Published var dailyEntries: [DailyEntry] = []

    // Пример агрегатов (по желанию можно использовать в UI)
    var totalIncome: Double { incomes.reduce(0) { $0 + $1.amount } }
    var totalExpense: Double { expenses.reduce(0) { $0 + $1.amount } }

    // MARK: - Приватное

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Инициализация

    init() {
        startAutoSave()
    }

    // MARK: - Методы изменения данных (используются из вью)

    func addIncome(_ income: Income) {
        incomes.append(income)
    }

    func addExpense(_ expense: Expense) {
        expenses.append(expense)
    }

    func addGoal(_ goal: Goal) {
        goals.append(goal)
    }

    func addDebt(_ debt: Debt) {
        debts.append(debt)
    }

    func addDailyEntry(_ entry: DailyEntry) {
        dailyEntries.append(entry)
    }

    // MARK: - Автосохранение через Combine

    /// Настраивает авто-сохранение при любом изменении основных массивов.
    private func startAutoSave() {
        // Приводим все источники к единому типу AnyPublisher<Void, Never>,
        // чтобы корректно объединить через MergeMany.
        let p1 = $incomes.map { _ in () }.eraseToAnyPublisher()
        let p2 = $expenses.map { _ in () }.eraseToAnyPublisher()
        let p3 = $debts.map { _ in () }.eraseToAnyPublisher()
        let p4 = $goals.map { _ in () }.eraseToAnyPublisher()
        let p5 = $dailyEntries.map { _ in () }.eraseToAnyPublisher()

        Publishers.MergeMany([p1, p2, p3, p4, p5])
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.persist()
            }
            .store(in: &cancellables)
    }

    // MARK: - Простая персистенция на диск
    // Если у тебя есть собственный сервис Persistence.swift — можно
    // заменить реализацию persist()/loadFromDisk() на вызовы этого сервиса.

    private static let fileName = "appstate.json"

    private var saveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("FinMind", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent(Self.fileName)
    }

    /// Сохранить текущее состояние (JSON).
    private func persist() {
        // Кодирование выполняем не на главной очереди, чтобы не блокировать UI.
        let snapshot = self
        DispatchQueue.global(qos: .utility).async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: snapshot.saveURL, options: .atomic)
            } catch {
                #if DEBUG
                print("Persist error:", error)
                #endif
            }
        }
    }

    /// Загрузить состояние с диска (если нужно использовать при старте).
    func loadFromDiskIfAvailable() {
        let url = saveURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode(AppState.self, from: data)
            // Обновляем данные на главной очереди, чтобы уведомить подписчиков.
            DispatchQueue.main.async {
                self.incomes = loaded.incomes
                self.expenses = loaded.expenses
                self.debts = loaded.debts
                self.goals = loaded.goals
                self.dailyEntries = loaded.dailyEntries
            }
        } catch {
            #if DEBUG
            print("Load error:", error)
            #endif
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case incomes, expenses, debts, goals, dailyEntries
    }

    // Поскольку @Published не кодируются автоматически, делаем ручную реализацию.

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        incomes      = (try? c.decode([Income].self, forKey: .incomes)) ?? []
        expenses     = (try? c.decode([Expense].self, forKey: .expenses)) ?? []
        debts        = (try? c.decode([Debt].self, forKey: .debts)) ?? []
        goals        = (try? c.decode([Goal].self, forKey: .goals)) ?? []
        dailyEntries = (try? c.decode([DailyEntry].self, forKey: .dailyEntries)) ?? []
        startAutoSave()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(incomes,      forKey: .incomes)
        try c.encode(expenses,     forKey: .expenses)
        try c.encode(debts,        forKey: .debts)
        try c.encode(goals,        forKey: .goals)
        try c.encode(dailyEntries, forKey: .dailyEntries)
    }
}
