import Foundation

extension AppState {
    /// Полная очистка всех пользовательских данных
    func wipeAllData() {
        // Основные сущности
        incomes.removeAll()
        expenses.removeAll()
        debts.removeAll()
        goals.removeAll()

        // Если используешь ежедневные записи/плановые
        if !(dailyEntries.isEmpty) { dailyEntries.removeAll() }

        // «Сбережения»
        if !(reserves.isEmpty) { reserves.removeAll() }

        // История советника (если есть)
        ChatStorage.shared.clear()

        // Обновим метку времени курсов (как пустое состояние)
        rates.updatedAt = nil

        // Сразу сохраним
        forceSave()
    }
}
