import SwiftUI

struct ScoreLibraryView: View {
    @State private var scores = ScoreService.shared.scores
    @State private var searchText = ""
    @State private var selectedScore: Score?

    let onSelect: ((Score) -> Void)?

    init(onSelect: ((Score) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    var filteredScores: [Score] {
        if searchText.isEmpty { return scores }
        return scores.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.composer.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredScores) { score in
            Button {
                if let handler = onSelect {
                    handler(score)
                } else {
                    selectedScore = score
                }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(score.title)
                            .font(.headline)
                        HStack {
                            Text(score.composer)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(score.tempo) BPM")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(score.measures.count) 小节")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("曲库")
        .searchable(text: $searchText, prompt: "搜索曲目")
        .sheet(item: $selectedScore) { score in
            NavigationStack {
                VStack {
                    ScoreView(
                        score: score,
                        currentNoteIndex: -1,
                        judgments: []
                    )
                    .padding()
                    Spacer()
                    Text("返回练习页选择此曲并开始")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle(score.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("关闭") {
                            selectedScore = nil
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ScoreLibraryView()
}
