# FinMind Starter (SwiftUI)
Минимальный каркас приложения с 4 вкладками: Обзор, План, Календарь, Настройки.

## Файлы
- `ContentView.swift`
- `Views/OverviewView.swift`
- `Views/PlanView.swift`
- `Views/CalendarView.swift`
- `Views/SettingsView.swift`
- `Models/BudgetItems.swift`
- `Models/UserProfile.swift`
- `Models/Plan.swift`
- `.gitignore`

## Как подключить к новому проекту Xcode
1. Создай проект **iOS App (SwiftUI)**.
2. Удали/очисти стандартный `ContentView.swift` (или замени его содержимым из этого набора).
3. Добавь папки `Views/` и `Models/` в проект (**File → Add Files to "… "** → выбери папки, *Copy if needed* можно оставить выключенным).
4. Собери проект (⌘B).

> Если в проекте уже есть файл с аннотацией `@main` (например, `HelloWorldApp.swift`), **не добавляй отдельный `FinMindApp.swift`**, просто оставь существующий `@main` и убедись, что в нём `WindowGroup { ContentView() }`.
