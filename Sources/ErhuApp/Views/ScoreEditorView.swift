import SwiftUI

struct ScoreEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var jianpuText: String
    @State private var parsedScore: Score?
    @State private var parseError: JianpuParser.ParseError?
    @State private var title: String
    @State private var showPreview = false

    private let editScore: Score?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("曲谱标题", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("简谱说明：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("1-7 = 音符, 0 = 休止, 空格分隔, | = 小节线")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("数字后 . = 高八度, 数字前 . = 低八度")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("数字后 - = 2拍, 数字后 _ = 4拍")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)

                TextEditor(text: $jianpuText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .onChange(of: jianpuText) { _, _ in tryParse() }

                if let error = parseError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                if let score = parsedScore, parseError == nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("解析成功: \(score.measures.count) 个小节")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Spacer()
                        Button("预览") { showPreview = true }
                            .font(.caption)
                            .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            .navigationTitle(editScore != nil ? "编辑曲谱" : "新建曲谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveScore() }
                        .disabled(jianpuText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseError != nil)
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            if let score = parsedScore {
                NavigationStack {
                    ScoreView(score: score, currentNoteIndex: -1, judgments: [])
                        .padding()
                        .navigationTitle("预览")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("关闭") { showPreview = false }
                            }
                        }
                }
            }
        }
    }

    init(score: Score? = nil) {
        editScore = score
        _title = State(initialValue: score?.title ?? "")
        _jianpuText = State(initialValue: score != nil ? scoreToText(score!) : "")
    }

    init(score: Score) {
        self.init(score: score)
    }

    private func tryParse() {
        let text = jianpuText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            parsedScore = nil
            parseError = nil
            return
        }
        do {
            parsedScore = try JianpuParser.parse(text)
            parseError = nil
        } catch let err as JianpuParser.ParseError {
            parseError = err
            parsedScore = nil
        } catch {
            parseError = JianpuParser.ParseError(line: 1, position: 1, message: error.localizedDescription)
            parsedScore = nil
        }
    }

    private func saveScore() {
        guard let score = parsedScore else { return }
        var saved = score
        saved.title = title.trimmingCharacters(in: .whitespaces).isEmpty ? "未命名" : title
        saved.isCustom = true
        saved.difficulty = .beginner

        if let existing = editScore {
            ScoreService.shared.updateCustomScore(id: existing.id, newScore: saved)
        } else {
            ScoreService.shared.addCustomScore(saved)
        }
        dismiss()
    }
}

/// Convert a Score back to jianpu text (for editing existing scores)
private func scoreToText(_ score: Score) -> String {
    score.measures.map { measure in
        measure.notes.map { note in
            var token = ""
            if note.octave < 0 {
                token += String(repeating: ".", count: abs(note.octave))
            }
            token += "\(note.degree)"
            if note.octave > 0 {
                token += String(repeating: ".", count: note.octave)
            }
            if note.duration == 2.0 {
                token += "-"
            } else if note.duration == 4.0 {
                token += "_"
            }
            return token
        }.joined(separator: " ")
    }.joined(separator: " | ")
}
