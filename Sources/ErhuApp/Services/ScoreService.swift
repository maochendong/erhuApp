import Foundation

/// Provides built-in erhu scores and manages score data
final class ScoreService: @unchecked Sendable {
    static let shared = ScoreService()

    var scores: [Score] = []
    /// User-created custom scores (lives in-memory for the session)
    var customScores: [Score] = []
    /// Persisted favorite score IDs
    private var favoriteIds: Set<UUID> = []

    private init() {
        loadFavorites()
        scores = builtInScores()
        // Apply saved favorites to built-in scores
        for i in scores.indices {
            if favoriteIds.contains(scores[i].id) {
                scores[i].isFavorite = true
            }
        }
    }

    /// All scores including custom ones
    var allScores: [Score] {
        scores + customScores
    }

    func score(by id: UUID) -> Score? {
        allScores.first { $0.id == id }
    }

    func addCustomScore(_ score: Score) {
        customScores.append(score)
    }

    func updateCustomScore(id: UUID, newScore: Score) {
        if let idx = customScores.firstIndex(where: { $0.id == id }) {
            customScores[idx] = newScore
        }
    }

    func deleteCustomScore(id: UUID) {
        customScores.removeAll { $0.id == id }
    }

    // MARK: - Favorites

    func toggleFavorite(scoreId: UUID) {
        if favoriteIds.contains(scoreId) {
            favoriteIds.remove(scoreId)
        } else {
            favoriteIds.insert(scoreId)
        }
        if let idx = scores.firstIndex(where: { $0.id == scoreId }) {
            scores[idx].isFavorite.toggle()
        }
        saveFavorites()
    }

    func isFavorite(scoreId: UUID) -> Bool {
        favoriteIds.contains(scoreId)
    }

    var favoritedScoreIds: Set<UUID> { favoriteIds }

    private func saveFavorites() {
        let ids = Array(favoriteIds).map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: "favoriteScoreIds")
    }

    private func loadFavorites() {
        guard let ids = UserDefaults.standard.stringArray(forKey: "favoriteScoreIds") else { return }
        favoriteIds = Set(ids.compactMap { UUID(uuidString: $0) })
    }

    // MARK: - Built-in scores (12+ pieces)

    private func builtInScores() -> [Score] {
        levelBeginner() + levelElementary() + levelIntermediate() + levelAdvanced1()
        + levelAdvanced2() + levelAdvanced3()
    }

    private func levelBeginner() -> [Score] {
        [
            makeScore(title: "小星星", composer: "传统儿歌", tempo: 100, difficulty: .beginner, notes: [1,1,5,5,6,6,5, 4,4,3,3,2,2,1, 5,5,4,4,3,3,2, 5,5,4,4,3,3,2, 1,1,5,5,6,6,5, 4,4,3,3,2,2,1]),
            makeScore(title: "两只老虎", composer: "传统儿歌", tempo: 110, difficulty: .beginner, notes: [1,2,3,1, 1,2,3,1, 3,4,5, 3,4,5, 5,6,5,4,3,1, 5,6,5,4,3,1, 2,5,1, 2,5,1]),
            makeScore(title: "摇篮曲", composer: "东北民歌", tempo: 70, difficulty: .beginner, notes: [1,1,5, 5,6,5, 3,3,2, 1,0, 5,5,3, 3,2,1, 6,5,3, 2,0, 1,1,5, 5,6,5, 3,3,2, 1,0, 5,5,3, 3,2,1, 2,2,1, 1,0, 3,3,5, 6,5,3, 5,3,2, 1,0, 5,5,3, 3,2,1, 6,5,3, 2,0, 1,1,5, 5,6,5, 3,3,2, 1,0, 5,5,3, 3,2,1, 2,2,1, 1,0]),
            makeScore(title: "田园春色", composer: "陈振铎", tempo: 90, difficulty: .beginner, notes: [5,6,5,6, 5,3,2,3, 5,6,1,2, 3,2,3,5, 6,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,5,6, 1,0,0,0, 5,6,5,3, 2,3,2,1, 6,1,2,3, 5,3,5,6, 1,2,1,6, 5,6,5,3, 2,3,5,6, 1,0,0,0]),
            makeScore(title: "我爱北京天安门", composer: "金月苓", tempo: 100, difficulty: .beginner, notes: [5,1,5,3, 2,3,2,1, 5,1,5,3, 2,3,2,1, 5,6,5,3, 1,3,5,6, 5,3,2,3, 1,0,0,0, 5,1,5,3, 2,3,2,1, 5,1,5,3, 2,3,2,1, 5,6,5,3, 1,3,5,6, 5,3,2,3, 1,0,0,0]),
            makeScore(title: "绣金匾", composer: "陕北民歌", tempo: 80, difficulty: .beginner, notes: [5,5,6,1, 6,5,3,0, 2,3,2,1, 6,5,3,0, 5,5,6,1, 6,5,3,0, 2,3,2,1, 6,5,6,0, 1,0,0,0, 5,6,1,2, 3,5,3,2, 1,2,3,5, 2,1,6,0, 5,5,6,1, 6,5,3,0, 2,3,2,1, 6,5,6,0, 1,0,0,0]),
            makeScore(title: "八月桂花遍地开", composer: "江西民歌", tempo: 100, difficulty: .beginner, notes: [5,6,1,6, 5,6,5,3, 5,6,1,6, 5,0,0,0, 5,6,1,2, 6,5,3,0, 2,3,2,1, 2,0,0,0, 5,6,1,6, 5,6,5,3, 5,6,1,2, 6,5,3,0, 2,3,2,1, 2,3,2,1, 6,5,6,1, 5,0,0,0]),
            makeScore(title: "南泥湾", composer: "马可", tempo: 85, difficulty: .beginner, notes: [5,5,6,1, 3,2,1,0, 6,1,6,5, 3,0,0,0, 5,5,6,1, 3,2,1,0, 6,1,6,5, 3,0,0,0, 1,1,6,1, 3,2,3,0, 6,5,3,2, 1,0,0,0, 5,5,6,1, 3,2,1,0, 6,5,3,2, 1,0,0,0]),
        ]
    }

    private func levelElementary() -> [Score] {
        [
            makeScore(title: "茉莉花", composer: "江苏民歌", tempo: 80, difficulty: .elementary, notes: [5,5,6,1,6,5, 5,5,6,1,6,5, 6,1,3,2,3, 6,1,3,2,3, 5,6,5,3,2,3,5,3,2, 3,2,1,3,2,1, 3,2,1,3,2,1, 1,2,3,2,1, 6,1,5,6,1,5, 3,2,3,5,3,2, 1,3,2,1, 1,3,2,1]),
            makeScore(title: "小花鼓", composer: "刘北茂", tempo: 110, difficulty: .elementary, notes: [3,3,5,3, 2,3,5,6, 3,3,5,3, 2,3,5,6, 5,5,6,5, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 6,5,6,1, 5,0,0,0, 3,3,5,3, 2,3,5,6, 3,3,5,3, 2,3,5,6, 5,5,6,5, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,5,6, 3,2,1,2, 1,0,0,0]),
            makeScore(title: "采茶扑蝶", composer: "福建民歌", tempo: 105, difficulty: .elementary, notes: [6,5,6,5, 6,1,6,5, 3,5,6,5, 3,2,1,2, 6,5,6,5, 6,1,6,5, 3,5,6,5, 3,2,1,2, 5,6,5,3, 2,3,2,1, 2,3,2,1, 6,5,6,1, 5,0,0,0, 6,5,6,5, 6,1,6,5, 3,5,6,5, 3,2,1,0]),
            makeScore(title: "金蛇狂舞", composer: "聂耳", tempo: 130, difficulty: .elementary, notes: [5,6,5,6, 5,3,5,0, 1,2,1,2, 5,6,5,0, 5,6,5,6, 5,3,5,0, 1,2,1,2, 5,6,1,0, 5,6,5,6, 5,3,5,0, 1,2,1,2, 5,6,5,0, 5,6,1,2, 3,2,3,5, 6,5,6,1, 2,0,0,0, 5,6,1,2, 3,2,3,5, 6,5,6,1, 2,1,2,3, 2,1,2,3, 5,3,5,6, 1,0,0,0]),
            makeScore(title: "翻身歌", composer: "张撷诚", tempo: 95, difficulty: .elementary, notes: [3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,0, 1,1,6,1, 3,5,3,2, 1,2,3,5, 2,1,6,0, 1,1,6,1, 3,5,3,2, 1,2,3,5, 2,1,6,0, 1,2,3,5, 6,5,6,1, 5,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,0, 1,0,0,0]),
        ]
    }

    private func levelIntermediate() -> [Score] {
        [
            makeScore(title: "赛马", composer: "黄海怀", tempo: 150, difficulty: .intermediate, notes: [3,3,5, 6,6,5, 3,3,5, 6,6,5, 1,1,2, 3,3,2, 1,1,2, 3,3,2, 5,5,3, 2,2,1, 5,5,3, 2,2,1, 6,6,5, 3,3,2, 1,1,2, 3,3,5, 6,6,5, 3,3,5, 6,6,1, 2,2,1, 6,6,5, 3,3,5, 6,6,5, 3,3,5, 1,1,2, 3,3,2, 1,1,2, 3,3,2, 5,5,3, 2,2,1, 5,5,3, 2,2,1, 6,6,5, 3,3,2, 1,1,2, 3,3,5, 6,6,5, 3,3,5, 6,6,1, 2,2,1]),
            makeScore(title: "良宵", composer: "刘天华", tempo: 80, difficulty: .intermediate, notes: [3,3,5, 6,1,6, 5,3,5, 6,5,3, 2,3,5, 6,5,3, 2,1,2, 3,0, 5,6,1, 2,1,6, 5,3,2, 1,0, 5,5,6, 1,2,1, 6,5,3, 5,0, 3,2,3, 5,6,5, 3,2,1, 2,1,2, 3,5,6, 1,2,1, 6,5,3, 5,6,5, 3,2,3, 5,6,5, 3,2,1, 2,1,2, 3,5,6, 1,6,5, 3,2,1, 1,0]),
            makeScore(title: "光明行", composer: "刘天华", tempo: 120, difficulty: .intermediate, notes: [1,1,1, 3,3,3, 5,5,5, 6,6,6, 1,1,1, 3,3,3, 5,5,5, 6,6,6, 5,6,5,3, 2,3,2,1, 5,6,5,3, 2,3,2,1, 2,1,2,3, 5,3,5,6, 1,6,1,2, 3,2,3,5, 6,1,6,5, 6,1,6,5, 3,5,3,2, 3,5,3,2, 1,2,1,6, 1,2,1,6, 5,6,5,3, 5,6,5,3, 2,3,2,1, 2,3,2,1, 1,0]),
            makeScore(title: "月夜", composer: "刘天华", tempo: 70, difficulty: .intermediate, notes: [5,5,6, 1,2,3, 5,3,2, 1,6,5, 3,5,6, 1,6,5, 3,2,3, 5,0, 5,6,1, 2,3,2, 1,6,5, 3,0, 2,3,5, 6,1,6, 5,3,2, 1,0, 1,2,3, 5,6,5, 3,2,1, 6,0, 5,6,1, 2,1,6, 5,3,2, 1,0, 5,5,6, 1,2,3, 5,3,2, 1,6,5, 3,5,6, 1,6,5, 3,2,1, 1,0]),
            makeScore(title: "喜送公粮", composer: "顾武祥、孟津津", tempo: 110, difficulty: .intermediate, notes: [5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 3,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 6,1,6,5, 3,5,3,2, 1,2,3,5, 2,1,6,5, 1,0,0,0]),
            makeScore(title: "山丹丹花开红艳艳", composer: "刘烽", tempo: 80, difficulty: .intermediate, notes: [2,2,3,0, 5,5,6,0, 2,3,2,1, 6,5,6,0, 2,2,3,0, 5,5,6,0, 2,3,2,1, 6,5,6,0, 5,5,3,0, 2,3,2,1, 6,5,6,1, 2,0,0,0, 5,5,3,0, 2,3,2,1, 6,5,6,1, 2,0,0,0, 3,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0, 5,5,6,0, 2,3,2,1, 6,5,6,1, 2,0,0,0]),
            makeScore(title: "北京有个金太阳", composer: "藏族民歌", tempo: 100, difficulty: .intermediate, notes: [5,6,1,6, 5,6,5,3, 5,6,1,6, 5,3,2,1, 5,6,1,6, 5,6,5,3, 5,6,1,6, 5,3,2,1, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 1,2,3,5, 6,5,6,1, 5,0,0,0, 5,6,1,6, 5,6,5,3, 5,6,1,6, 5,3,2,1, 1,0,0,0]),
            makeScore(title: "花欢乐", composer: "民间乐曲", tempo: 85, difficulty: .intermediate, notes: [3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 6,1,6,5, 3,5,3,2, 1,2,3,5, 2,1,6,5, 1,0,0,0, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 6,1,6,5, 3,5,3,2, 1,2,3,5, 2,3,2,1, 6,5,6,1, 5,0,0,0]),
            makeScore(title: "豫北叙事曲", composer: "刘文金", tempo: 75, difficulty: .intermediate, notes: [3,3,2,0, 1,2,3,5, 6,5,6,1, 5,0,0,0, 5,5,6,0, 1,2,6,5, 3,2,3,5, 2,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 3,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0]),
            makeScore(title: "江南春色", composer: "朱昌耀", tempo: 85, difficulty: .intermediate, notes: [3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 6,1,6,5, 3,5,3,2, 1,2,3,5, 2,1,6,5, 1,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 3,5,6,1, 2,3,2,1, 6,5,6,1, 5,0,0,0, 6,1,6,5, 3,5,3,2, 1,2,3,5, 2,3,2,1, 6,5,6,1, 5,0,0,0, 1,0,0,0]),
        ]
    }

    private func levelAdvanced1() -> [Score] {
        [
            makeScore(title: "二泉映月", composer: "阿炳", tempo: 60, difficulty: .advanced, notes: [6,5,6, 1,2,3, 5,6,5, 3,2,3, 5,6,5, 3,2,1, 6,5,6, 1,0, 2,3,5, 6,5,3, 2,3,2, 1,0, 5,6,1, 2,3,2, 1,6,5, 3,0, 6,5,6, 1,2,3, 5,6,5, 3,2,3, 5,6,5, 3,2,1, 6,5,6, 1,0, 2,3,5, 6,5,3, 2,3,2, 1,0, 5,6,1, 2,3,2, 1,6,5, 3,0, 6,5,6, 1,2,3, 5,6,5, 3,2,3, 5,6,5, 3,2,1, 6,5,6, 1,0]),
            makeScore(title: "空山鸟语", composer: "刘天华", tempo: 90, difficulty: .advanced, notes: [1,2,3, 5,3,2, 1,2,3, 5,3,2, 1,0, 1,2,3, 5,6,5, 3,2,1, 3,5,3, 2,1,2, 3,5,3, 2,1,2, 1,6,1, 2,3,2, 1,6,1, 2,3,2, 5,3,5, 6,1,6, 5,3,5, 6,1,6, 1,2,3, 5,6,5, 3,2,1, 2,3,2, 1,6,1, 2,3,2, 1,6,1, 2,3,2, 1,6,5, 3,2,1, 1,0]),
            makeScore(title: "江河水", composer: "东北民间", tempo: 50, difficulty: .advanced, notes: [1,1, 6,5,6, 1,2,3, 5,3,2, 1,6,5, 6,1,6, 5,3,2, 1,0, 3,5,6, 1,6,5, 3,2,3, 5,0, 3,2,1, 6,5,6, 1,2,3, 5,3,2, 1,6,5, 6,1,6, 5,3,2, 1,0, 5,6,1, 2,3,2, 1,6,5, 3,0, 6,5,6, 1,2,3, 5,6,5, 3,2,1, 2,3,2, 1,6,5, 6,1,6, 5,3,2, 1,6,5, 6,1,6, 5,3,2, 1,0]),
            makeScore(title: "三门峡畅想曲", composer: "刘文金", tempo: 130, difficulty: .advanced, notes: [5,6,1, 2,3,5, 6,1,2, 3,0, 2,1,6, 5,3,2, 1,6,5, 3,0, 5,6,1, 2,3,5, 6,1,2, 3,0, 2,1,6, 5,3,2, 1,6,5, 3,0, 6,5,3, 2,3,5, 6,5,3, 2,0, 1,2,3, 5,3,2, 1,6,5, 6,0, 5,6,1, 2,3,5, 6,1,2, 3,0, 2,1,6, 5,3,2, 1,6,5, 3,0, 5,6,1, 2,3,5, 6,1,2, 3,0, 2,1,6, 5,3,2, 1,0]),
        ]
    }

    private func levelAdvanced2() -> [Score] {
        [
            makeScore(title: "病中吟", composer: "刘天华", tempo: 55, difficulty: .advanced, notes: [1,2,3,5, 6,5,3,2, 1,2,3,5, 6,0,0,0, 5,6,1,2, 6,5,3,2, 3,2,1,6, 5,0,0,0, 1,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 5,6,1,2, 6,5,3,2, 1,2,3,5, 6,0,0,0, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0]),
            makeScore(title: "听松", composer: "阿炳", tempo: 60, difficulty: .advanced, notes: [1,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 1,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 3,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0, 5,6,1,2, 3,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0, 1,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0]),
            makeScore(title: "独弦操", composer: "刘天华", tempo: 65, difficulty: .advanced, notes: [1,2,3,5, 6,1,6,5, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 6,5,6,1, 5,0,0,0, 1,2,3,5, 6,1,6,5, 3,5,3,2, 1,2,1,6, 5,6,5,3, 2,3,2,1, 6,5,6,1, 5,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,2,3,5, 6,5,6,1, 5,3,2,3, 5,0,0,0, 1,0,0,0]),
            makeScore(title: "闲居吟", composer: "刘天华", tempo: 70, difficulty: .advanced, notes: [3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 5,6,1,2, 3,2,3,5, 6,5,3,2, 1,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0, 6,1,6,5, 3,5,3,2, 1,2,3,5, 2,1,6,5, 1,0,0,0, 5,6,1,2, 3,2,3,5, 6,5,3,2, 1,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,1,5,6, 1,0,0,0]),
        ]
    }

    private func levelAdvanced3() -> [Score] {
        [
            makeScore(title: "烛影摇红", composer: "刘天华", tempo: 75, difficulty: .advanced, notes: [3,2,3,5, 6,1,6,5, 3,2,3,5, 6,0,0,0, 3,2,3,5, 6,1,6,5, 3,2,3,5, 6,0,0,0, 5,6,1,2, 3,5,3,2, 1,2,3,5, 2,0,0,0, 3,2,3,5, 6,1,6,5, 3,2,3,5, 6,0,0,0, 5,6,1,2, 3,5,3,2, 1,2,6,5, 1,0,0,0, 3,2,3,5, 6,1,6,5, 3,5,6,1, 5,0,0,0, 5,6,1,2, 3,5,3,2, 1,2,6,5, 1,0,0,0]),
            makeScore(title: "汉宫秋月", composer: "古曲", tempo: 50, difficulty: .advanced, notes: [2,3,5,6, 3,2,3,5, 6,5,3,2, 1,0,0,0, 2,3,5,6, 3,2,3,5, 6,5,3,2, 1,0,0,0, 3,5,6,1, 5,6,5,3, 2,3,2,1, 6,5,6,0, 1,0,0,0, 2,3,5,6, 3,2,3,5, 6,5,3,2, 1,0,0,0, 5,6,1,2, 3,5,3,2, 1,2,3,5, 2,3,2,1, 6,5,6,1, 5,0,0,0, 2,3,5,6, 3,2,3,5, 6,5,3,2, 1,0,0,0]),
        ]
    }

    private func makeScore(title: String, composer: String, tempo: Int, difficulty: Difficulty, notes: [Int]) -> Score {
        var measures: [Measure] = []
        var currentNotes: [Note] = []

        for value in notes {
            if value == 0 {
                currentNotes.append(Note(degree: 0, duration: 1.0))
            } else {
                currentNotes.append(Note(degree: value, duration: 1.0))
            }

            if currentNotes.count == 4 {
                measures.append(Measure(notes: currentNotes))
                currentNotes = []
            }
        }

        if !currentNotes.isEmpty {
            measures.append(Measure(notes: currentNotes))
        }

        return Score(
            title: title,
            composer: composer,
            tempo: tempo,
            difficulty: difficulty,
            measures: measures
        )
    }
}
