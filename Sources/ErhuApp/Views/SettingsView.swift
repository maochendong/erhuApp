import SwiftUI

struct SettingsView: View {
    @State private var audioSensitivity: Double = 0.5
    @State private var showAllNotes: Bool = false
    @State private var notificationsEnabled = NotificationManager.shared.isNotificationEnabled
    @State private var reminderHour: Int = NotificationManager.shared.reminderHour
    @State private var reminderMinute: Int = NotificationManager.shared.reminderMinute
    @State private var showCalendar = false

    var body: some View {
        NavigationStack {
            Form {
                Section("音频设置") {
                    VStack(alignment: .leading) {
                        Text("麦克风灵敏度: \(Int(audioSensitivity * 100))%")
                        Slider(value: $audioSensitivity, in: 0.1...1.0)
                    }
                }

                Section("练习设置") {
                    Toggle("显示所有音符参考", isOn: $showAllNotes)
                    Button {
                        showCalendar = true
                    } label: {
                        HStack {
                            Text("练习日历")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("提醒设置") {
                    Toggle(isOn: Binding(
                        get: { notificationsEnabled },
                        set: { newValue in
                            notificationsEnabled = newValue
                            NotificationManager.shared.isNotificationEnabled = newValue
                            if newValue {
                                NotificationManager.shared.requestPermission { granted in
                                    if granted {
                                        NotificationManager.shared.scheduleDailyReminder(
                                            hour: reminderHour, minute: reminderMinute
                                        )
                                    } else {
                                        notificationsEnabled = false
                                    }
                                }
                            } else {
                                NotificationManager.shared.cancelAll()
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text("每日练习提醒")
                            Text("提醒你每天坚持练习")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if notificationsEnabled {
                        HStack {
                            Text("提醒时间")
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: {
                                        Calendar.current.date(
                                            from: DateComponents(hour: reminderHour, minute: reminderMinute)
                                        ) ?? Date()
                                    },
                                    set: { date in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        reminderHour = comps.hour ?? 19
                                        reminderMinute = comps.minute ?? 0
                                        NotificationManager.shared.reminderHour = reminderHour
                                        NotificationManager.shared.reminderMinute = reminderMinute
                                        NotificationManager.shared.scheduleDailyReminder(
                                            hour: reminderHour, minute: reminderMinute
                                        )
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }

                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("二胡识谱")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("内置曲目")
                        Spacer()
                        Text("12 首")
                            .foregroundStyle(.secondary)
                    }
                    Text("二胡识谱是一款帮助二胡学习者练习识谱和音准的教学工具。通过实时音高检测，判断演奏是否准确。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showCalendar) {
                NavigationStack {
                    PracticeCalendarView()
                        .navigationTitle("练习日历")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("关闭") { showCalendar = false }
                            }
                        }
                }
            }
        }
    }
}

struct PracticeCalendarView: View {
    @State private var selectedDate = Date()
    @State private var monthRecords: [Date: Int] = [:]
    @State private var practiceDates: Set<Date> = []
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(currentMonth, format: .dateTime.year().month(.wide))
                    .font(.title3.weight(.medium))

                Spacer()

                Button {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Day of week headers
            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Calendar grid
            let days = generateDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if calendar.isDate(date, equalTo: currentMonth, toGranularity: .month) {
                        let day = calendar.component(.day, from: date)
                        let hasPractice = practiceDates.contains { calendar.isDate($0, inSameDayAs: date) }

                        VStack(spacing: 2) {
                            Text("\(day)")
                                .font(.callout)
                                .foregroundStyle(calendar.isDateInToday(date) ? Color.accentColor : .primary)

                            if hasPractice {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(calendar.isDateInToday(date) ? Color.accentColor.opacity(0.1) : .clear)
                        )
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("已练习")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.accentColor.opacity(0.3)).frame(width: 8, height: 8)
                    Text("今天")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical)
        .onAppear {
            practiceDates = NotificationManager.shared.practiceDates
        }
    }

    private func generateDays() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count

        var days: [Date] = []
        // Leading empty days
        for _ in 1..<firstWeekday {
            days.append(.distantPast)
        }
        // Actual days
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: currentMonth),
                                                              month: calendar.component(.month, from: currentMonth),
                                                              day: day)) {
                days.append(date)
            }
        }
        return days
    }
}

#Preview {
    SettingsView()
}
