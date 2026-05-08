import SwiftUI

struct SettingsView: View {
    @State private var audioSensitivity: Double = 0.5
    @State private var showAllNotes: Bool = false

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
                    Text("二胡识谱是一款帮助二胡学习者练习识谱和音准的教学工具。通过实时音高检测，判断演奏是否准确。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
}
