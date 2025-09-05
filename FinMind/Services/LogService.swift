import Foundation
import os.log

/// Категории логов
enum LogCategory: String {
    case app, network, rates, metals, error
}

/// Простой файловый логгер + Unified Logging (os.Logger)
final class Log {
    static let shared = Log()
    private init() {}

    // Включатель (храним в UserDefaults, ключ общий с экраном Диагностики)
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "diag.enabled")
    }

    // Очередь записи
    private let q = DispatchQueue(label: "fm.logger", qos: .utility)

    // Файлы: rotation на 512 КБ, 3 файла
    private let maxBytes: Int = 512 * 1024
    private let maxFiles: Int = 3

    private var logDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private var currentURL: URL { logDir.appendingPathComponent("finmind.log") }

    // Unified logging
    private let oslog = Logger(subsystem: "app.finmind", category: "general")

    // Публичные фасады
    static func i(_ cat: LogCategory, _ msg: String) { shared.write(cat, msg) }
    static func e(_ msg: String) { shared.write(.error, msg) }

    /// Прочитать «хвост» лога для отображения в UI
    func readTail(_ limitBytes: Int = 80_000) -> String {
        guard let data = try? Data(contentsOf: currentURL) else { return "" }
        if data.count <= limitBytes {
            return String(data: data, encoding: .utf8) ?? ""
        }
        let slice = data.suffix(limitBytes)
        return String(data: slice, encoding: .utf8) ?? ""
    }

    /// URL текущего файла (для экспорта / шаринга)
    func currentFileURL() -> URL { currentURL }

    /// Очистка
    func clear() {
        try? FileManager.default.removeItem(at: currentURL)
    }

    // MARK: - Core
    private func write(_ category: LogCategory, _ msg: String) {
        // Unified logging (в системный консоль)
        oslog.log("\(category.rawValue): \(msg, privacy: .public)")

        guard isEnabled else { return }
        let line = "[\(timestamp())] [\(category.rawValue.uppercased())] \(msg)\n"

        q.async {
            // дописываем
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.currentURL.path) {
                    if let fh = try? FileHandle(forWritingTo: self.currentURL) {
                        defer { try? fh.close() }
                        do {
                            try fh.seekToEnd()
                            try fh.write(contentsOf: data)
                        } catch {
                            // игнорируем, логгер не должен падать
                        }
                    }
                } else {
                    try? data.write(to: self.currentURL)
                }
            }
            // ротация
            self.rotateIfNeeded()
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: currentURL.path),
              let size = attrs[.size] as? NSNumber else { return }
        if size.intValue < maxBytes { return }

        // Сдвигаем *.log -> *.1.log -> *.2.log ...
        for i in stride(from: maxFiles - 1, through: 1, by: -1) {
            let src = logDir.appendingPathComponent("finmind.\(i).log")
            let dst = logDir.appendingPathComponent("finmind.\(i+1).log")
            if FileManager.default.fileExists(atPath: dst.path) {
                try? FileManager.default.removeItem(at: dst)
            }
            if FileManager.default.fileExists(atPath: src.path) {
                try? FileManager.default.moveItem(at: src, to: dst)
            }
        }
        let first = logDir.appendingPathComponent("finmind.1.log")
        if FileManager.default.fileExists(atPath: first.path) {
            try? FileManager.default.removeItem(at: first)
        }
        try? FileManager.default.moveItem(at: currentURL, to: first)
        try? Data().write(to: currentURL)
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
