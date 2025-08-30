import SwiftUI

struct CalendarView: View {
    @State private var date = Date()
    @AppStorage("firstWeekday") private var firstWeekday: Int = 2

    var body: some View {
        NavigationStack {
            DatePicker("Дата", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .environment(\.calendar, Calendar.custom(firstWeekday: firstWeekday))
                .padding()
                .navigationTitle("Календарь")
        }
    }
}

private extension Calendar {
    static func custom(firstWeekday: Int) -> Calendar {
        var c = Calendar.current
        c.firstWeekday = (1...7).contains(firstWeekday) ? firstWeekday : 2
        return c
    }
}

#Preview { CalendarView() }
