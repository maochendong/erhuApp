import SwiftUI

struct ScoreLibraryView: View {
    @State private var searchText = ""
    @State private var selectedScore: Score?
    @State private var showEditor = false
    @State private var showBuiltInPreview = false
    @State private var difficultyFilter: Difficulty? = nil
    @State private var showFavoritesOnly = false

    // MARK: - Preview playback
    @State private var samplePlayer: ErhuSamplePlayer?
    @State private var isPreviewing = false
    @State private var previewingScoreId: UUID?
    @State private var previewTask: Task<Void, Never>?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    let onSelect: ((Score) -> Void)?

    init(onSelect: ((Score) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    var filteredScores: [Score] {
        let all = ScoreService.shared.allScores
        return all.filter { score in
            let matchesSearch = searchText.isEmpty ||
                score.title.localizedCaseInsensitiveContains(searchText) ||
                score.composer.localizedCaseInsensitiveContains(searchText)
            let matchesDifficulty = difficultyFilter == nil || score.difficulty == difficultyFilter
            let matchesFavorites = !showFavoritesOnly || score.isFavorite
            return matchesSearch && matchesDifficulty && matchesFavorites
        }
    }

    var builtInScores: [Score] { filteredScores.filter { !$0.isCustom } }
    var customScores: [Score] { filteredScores.filter { $0.isCustom } }

    var body: some View {
        VStack(spacing: 0) {
            // Difficulty filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterButton(
                        title: "全部",
                        isSelected: difficultyFilter == nil && !showFavoritesOnly,
                        action: { difficultyFilter = nil; showFavoritesOnly = false }
                    )
                    ForEach(Difficulty.allCases, id: \.self) { diff in
                        FilterButton(
                            title: diff.label,
                            isSelected: difficultyFilter == diff,
                            color: difficultyColor(diff),
                            action: { difficultyFilter = diff; showFavoritesOnly = false }
                        )
                    }
                    FilterButton(
                        title: "收藏",
                        systemImage: "heart.fill",
                        isSelected: showFavoritesOnly,
                        color: .red,
                        action: { showFavoritesOnly = true; difficultyFilter = nil }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Group {
                if isRegularWidth {
                    // Grid layout for iPad
                    ScrollView {
                        VStack(spacing: 16) {
                            if !customScores.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("自定义曲谱")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)
                                    ], spacing: 12) {
                                        ForEach(customScores) { score in
                                            scoreCard(score)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            VStack(alignment: .leading) {
                                Text("内置曲库（\(builtInScores.count) 首）")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 12) {
                                    ForEach(builtInScores) { score in
                                        scoreCard(score)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    List {
                        if !customScores.isEmpty {
                            Section(header: Text("自定义曲谱")) {
                                ForEach(customScores) { score in
                                    scoreRow(score)
                                }
                            }
                        }

                        Section(header: Text("内置曲库（\(builtInScores.count) 首）")) {
                            ForEach(builtInScores) { score in
                                scoreRow(score)
                            }
                        }

                        if filteredScores.isEmpty {
                            if searchText.isEmpty {
                                ContentUnavailableView(
                                    "还没有自定义曲谱",
                                    systemImage: "music.note.text",
                                    description: Text("点击上方 '新建' 开始创建自己的曲谱")
                                )
                            } else {
                                ContentUnavailableView(
                                    "未找到结果",
                                    systemImage: "magnifyingglass",
                                    description: Text("尝试其他搜索关键词")
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle("曲库")
        .searchable(text: $searchText, prompt: "搜索曲目")
        .onDisappear { stopPreview() }
        .sheet(isPresented: $showEditor) {
            if let score = selectedScore {
                ScoreEditorView(score: score)
            } else {
                ScoreEditorView()
            }
        }
        .sheet(item: $selectedScore, onDismiss: {
            if !showEditor { selectedScore = nil }
        }) { score in
            NavigationStack {
                VStack {
                    ScoreView(score: score, currentNoteIndex: -1, judgments: [])
                        .padding()
                    Spacer()
                    Text("返回练习页选择此曲并开始")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle(score.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("关闭") { selectedScore = nil }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("新建") {
                    selectedScore = nil
                    showEditor = true
                }
            }
        }
    }

    private func scoreRow(_ score: Score) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(score.title)
                        .font(.headline)
                    if score.isCustom {
                        Text("自定义")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    Text(score.difficulty.label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor(score.difficulty).opacity(0.15))
                        .foregroundStyle(difficultyColor(score.difficulty))
                        .clipShape(Capsule())
                }
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

            HStack(spacing: 6) {
                Button {
                    startPreview(for: score)
                } label: {
                    if previewingScoreId == score.id && isPreviewing {
                        Image(systemName: "stop.fill")
                    } else {
                        Image(systemName: "speaker.wave.2")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isPreviewing && previewingScoreId != score.id)

                Button("查看") {
                    selectedScore = score
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("练习") {
                    onSelect?(score)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if score.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if score.isCustom {
                Button(role: .destructive) {
                    ScoreService.shared.deleteCustomScore(id: score.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading) {
            if score.isCustom {
                Button {
                    selectedScore = score
                    showEditor = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .tint(.blue)
            }
            Button {
                ScoreService.shared.toggleFavorite(scoreId: score.id)
            } label: {
                Label(score.isFavorite ? "取消收藏" : "收藏", systemImage: "heart")
            }
            .tint(.red)
        }
    }

    /// Card-style score display for iPad grid layout
    private func scoreCard(_ score: Score) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(score.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if score.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Text(score.composer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(score.difficulty.label)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(difficultyColor(score.difficulty).opacity(0.15))
                    .foregroundStyle(difficultyColor(score.difficulty))
                    .clipShape(Capsule())

                Spacer()

                Text("\(score.tempo) BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("\(score.measures.count) 小节 · \(score.allNotes.count) 音符")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Spacer()
                Button {
                    startPreview(for: score)
                } label: {
                    Label(previewingScoreId == score.id && isPreviewing ? "停止" : "试听",
                          systemImage: previewingScoreId == score.id && isPreviewing
                          ? "stop.fill" : "speaker.wave.2")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isPreviewing && previewingScoreId != score.id)

                Button("查看") {
                    selectedScore = score
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("练习") {
                    onSelect?(score)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(difficultyColor(score.difficulty).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Preview Playback

    private func startPreview(for score: Score) {
        // Toggle off if already previewing this score
        if previewingScoreId == score.id && isPreviewing {
            stopPreview()
            return
        }

        stopPreview()

        // For 赛马, play the full recording
        if samplePlayer == nil {
            samplePlayer = ErhuSamplePlayer()
        }

        guard let player = samplePlayer else { return }
        isPreviewing = true
        previewingScoreId = score.id

        if player.hasFullRecording(for: score.title) {
            player.playSaimaRecording()
            // Auto-stop after a reasonable duration
            previewTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds max
                await MainActor.run { stopPreview() }
            }
            return
        }

        // Play the first several notes as a melody preview
        let previewNotes = Array(score.allNotes.filter { !$0.isRest }.prefix(8))
        let beatDuration = 60.0 / Double(score.tempo)

        previewTask = Task {
            for note in previewNotes {
                if Task.isCancelled || !isPreviewing { break }

                let playDuration = max(note.duration * beatDuration * 0.7, 0.2)
                let gap = max(note.duration * beatDuration * 0.3, 0.05)

                player.play(note: note, duration: playDuration)
                try? await Task.sleep(nanoseconds: UInt64((playDuration + gap) * 1_000_000_000))
            }

            await MainActor.run { stopPreview() }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        samplePlayer?.stop()
        isPreviewing = false
        previewingScoreId = nil
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .elementary: return .blue
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct FilterButton: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    var color: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let image = systemImage {
                    Image(systemName: image)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
    }
}

#Preview {
    ScoreLibraryView()
}
