import Foundation
import os.log

/// Простая файловая персистенция всего AppState в Documents/AppState.json
final class Persistence {
    static let shared = Persistence()

    // Очередь для фоновой записи
    private let queue = DispatchQueue(label: "fm.persistence", qos: .utility)

    // Куда пишем файл состояния
    private let fileURL: URL

    // Кодировщики/декодеры
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Чтобы diff‑ить файлы и удобнее читать в бэкапе
        e.outputFormatting = [.sortedKeys]
        // Для стабильных дат
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private func makeISODecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
    private let defaultDecoder = JSONDecoder() // на случай старых файлов

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = dir.appendingPathComponent("AppState.json")
    }

    // MARK: - API

    /// Загрузка состояния. Если файла нет/битый — вернём пустое состояние.
    func load() -> AppState {
        do {
            let data = try Data(contentsOf: fileURL)
            // Сначала пробуем ISO‑8601, затем дефолт (на случай древних сохранений)
            if let state = try? makeISODecoder().decode(AppState.self, from: data) {
                return state
            } else if let state = try? defaultDecoder.decode(AppState.self, from: data) {
                return state
            } else {
                return AppState()
            }
        } catch {
            // файла ещё нет — обычная ситуация при первом запуске
            return AppState()
        }
    }

    /// Синхронное сохранение (используйте в ручных местах: forceSave / экспорт).
    func save(_ state: AppState) throws {
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Асинхронное сохранение (для авто‑сейва — не блокирует главный поток).
    func saveAsync(_ state: AppState) {
        // Снимок на момент записи не делаем: кодируем текущее состояние
        // в сериализованной очереди, чтобы не конкурировать за файл.
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(state)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                // В релизе можно заменить на os_log, чтобы не засорять консоль
                print("Persistence saveAsync error:", error)
            }
        }
    }
}
