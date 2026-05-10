import SwiftUI
import Charts

struct ProgressView: View {
    @State private var records: [PracticeRecordEntity] = []
    @State private var selectedRange: RangeOption = .all

    enum RangeOption: String, CaseIterable {
        case week = "7天"
        case month = "30天"
        case all = "全部"
    }

    var filteredRecords: [PracticeRecordEntity] {
        let calendar = Calendar.current
        let now = Date()
        switch selectedRange {
        case .week:
            let cutoff = calendar.date(byAdding: .day, value: -7, to: now)!
            return records.filter { $0.date >= cutoff }
        case .month:
            let cutoff = calendar.date(byAdding: .day, value: -30, to: now)!
            return records.filter { $0.date >= cutoff }
        case .all:
            return records
        }
    }

    var streakDays: Int {
        let calendar = Calendar.current
        let sortedDates = Set(records.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        for date in sortedDates {
            if calendar.isDate(date, inSameDayAs: checkDate) || calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: checkDate)!) {
                streak += 1
                checkDate = date
            } else {
                break
            }
        }
        return streak
    }

    var totalPracticeTime: TimeInterval {
        records.reduce(0) { $0 + $1.duration }
    }

    var bestAccuracy: Double {
        records.map(\.accuracy).max() ?? 0
    }

    var averageAccuracy: Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.accuracy } / Double(records.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "还没有练习记录",
                        systemImage: "chart.bar",
                        description: Text("开始练习吧！完成练习后，你的进度会显示在这里")
                    )
                } else {
                    contentView
                }
            }
            .navigationTitle("进度")
            .onAppear {
                records = PersistenceController.shared.fetchPracticeRecords()
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Range picker
                Picker("时间范围", selection: $selectedRange) {
                    ForEach(RangeOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Streak counter
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("连续练习 \(streakDays) 天")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)

                // Summary stats row
                HStack(spacing: 16) {
                    StatBadge(
                        value: "\(records.count)",
                        label: "总次数",
                        color: .blue
                    )
                    StatBadge(
                        value: formatDuration(totalPracticeTime),
                        label: "总时间",
                        color: .purple
                    )
                    StatBadge(
                        value: "\(Int(bestAccuracy * 100))%",
                        label: "最高",
                        color: .green
                    )
                    StatBadge(
                        value: "\(Int(averageAccuracy * 100))%",
                        label: "平均",
                        color: .orange
                    )
                }

                // Chart 1: Accuracy per session
                if !filteredRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("准确率趋势")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(filteredRecords.sorted(by: { $0.date < $1.date }), id: \.id) { record in
                                LineMark(
                                    x: .value("日期", record.date, unit: .day),
                                    y: .value("准确率", record.accuracy * 100)
                                )
                                .foregroundStyle(.blue)

                                PointMark(
                                    x: .value("日期", record.date, unit: .day),
                                    y: .value("准确率", record.accuracy * 100)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .chartYAxisLabel("准确率 (%)")
                        .chartXAxisLabel("日期")
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

                    // Chart 2: Daily practice time
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每日练习时间")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(dailyPracticeTime(), id: \.date) { entry in
                                BarMark(
                                    x: .value("日期", entry.date, unit: .day),
                                    y: .value("时间", entry.minutes)
                                )
                                .foregroundStyle(.purple.opacity(0.7))
                            }
                        }
                        .chartYAxisLabel("分钟")
                        .chartXAxisLabel("日期")
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

                    // Chart 3: Accuracy by degree
                    VStack(alignment: .leading, spacing: 8) {
                        Text("各音准确率")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(degreeAccuracy(), id: \.degree) { item in
                                BarMark(
                                    x: .value("音名", item.label),
                                    y: .value("准确率", item.accuracy * 100)
                                )
                                .foregroundStyle(degreeColor(item.degree))
                            }
                        }
                        .chartYAxisLabel("准确率 (%)")
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

                    // Recent practice list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近练习")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(records.prefix(10), id: \.id) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.scoreTitle)
                                        .font(.subheadline)
                                    Text(record.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(record.accuracy * 100))%")
                                    .font(.headline)
                                    .foregroundStyle(accuracyColor(record.accuracy))
                            }
                            .padding(.horizontal)
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Helpers

    private struct DailyTime: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Double
    }

    private func dailyPracticeTime() -> [DailyTime] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped.map { date, records in
            let totalMinutes = records.reduce(0.0) { $0 + $1.duration } / 60.0
            return DailyTime(date: date, minutes: totalMinutes)
        }.sorted { $0.date < $1.date }
    }

    private struct DegreeAccuracy: Identifiable {
        let id = UUID()
        let degree: Int
        let label: String
        let accuracy: Double
    }

    private func degreeAccuracy() -> [DegreeAccuracy] {
        var stats: [Int: (total: Int, correct: Int)] = [:]
        for record in filteredRecords {
            if let details = record.noteDetails {
                for detail in details where detail.degree > 0 {
                    var entry = stats[Int(detail.degree)] ?? (0, 0)
                    entry.total += 1
                    if detail.wasCorrect { entry.correct += 1 }
                    stats[Int(detail.degree)] = entry
                }
            }
        }
        return stats.sorted { $0.key < $1.key }.map { degree, data in
            DegreeAccuracy(degree: degree, label: noteName(degree),
                           accuracy: data.total > 0 ? Double(data.correct) / Double(data.total) : 0)
        }
    }

    private func degreeColor(_ degree: Int) -> Color {
        let colors: [Int: Color] = [1: .red, 2: .orange, 3: .yellow, 4: .green,
                                    5: .blue, 6: .purple, 7: .pink]
        return colors[degree] ?? .gray
    }

    private func noteName(_ degree: Int) -> String {
        switch degree {
        case 1: return "do"
        case 2: return "re"
        case 3: return "mi"
        case 4: return "fa"
        case 5: return "sol"
        case 6: return "la"
        case 7: return "si"
        default: return "—"
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.5 { return .orange }
        return .red
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        if m >= 60 {
            return "\(m/60)h\(m%60)m"
        }
        return "\(m)m\(s)s"
    }
}

#Preview {
    ProgressView()
}
