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

    // MARK: - Note data helpers

    private typealias ND = (degree: Int, duration: Double, octave: Int, isDotted: Bool)
    private func q(_ d: Int, _ o: Int = 0) -> ND { (d, 1.0, o, false) }
    private func h(_ d: Int, _ o: Int = 0) -> ND { (d, 2.0, o, false) }
    private func e(_ d: Int, _ o: Int = 0) -> ND { (d, 0.5, o, false) }
    private func dq(_ d: Int, _ o: Int = 0) -> ND { (d, 1.5, o, true) }
    private func r(_ dur: Double = 1.0) -> ND { (0, dur, 0, false) }
    /// Low octave quarter note (下方加点)
    private func qL(_ d: Int) -> ND { (d, 1.0, -1, false) }
    /// High octave quarter note (上方加点)
    private func qH(_ d: Int) -> ND { (d, 1.0, 1, false) }
    /// Low octave eighth note
    private func eL(_ d: Int) -> ND { (d, 0.5, -1, false) }
    /// High octave eighth note
    private func eH(_ d: Int) -> ND { (d, 0.5, 1, false) }

    // MARK: - Built-in scores (30+ pieces with proper notation)

    private func builtInScores() -> [Score] {
        var scores: [Score] = []
        scores.append(contentsOf: levelBeginner())
        scores.append(contentsOf: levelElementary())
        scores.append(contentsOf: levelIntermediate())
        scores.append(contentsOf: levelAdvanced1())
        scores.append(contentsOf: levelAdvanced2())
        scores.append(contentsOf: levelAdvanced3())
        return scores
    }

    private func levelBeginner() -> [Score] {
        let scores: [Score] = [
            makeScore(title: "小星星", composer: "传统儿歌", tempo: 100, difficulty: .beginner, noteData: [
                // 一闪一闪亮晶晶，满天都是小星星
                q(1), q(1), q(5), q(5), q(6), q(6), h(5),
                q(4), q(4), q(3), q(3), q(2), q(2), h(1),
                // 挂在天上放光明，好像许多小眼睛
                q(5), q(5), q(4), q(4), q(3), q(3), h(2),
                q(5), q(5), q(4), q(4), q(3), q(3), h(2),
                // 一闪一闪亮晶晶，满天都是小星星
                q(1), q(1), q(5), q(5), q(6), q(6), h(5),
                q(4), q(4), q(3), q(3), q(2), q(2), h(1),
            ]),
            makeScore(title: "两只老虎", composer: "传统儿歌", tempo: 110, difficulty: .beginner, noteData: [
                q(1), q(2), q(3), q(1), q(1), q(2), q(3), q(1),
                q(3), q(4), h(5), q(3), q(4), h(5),
                e(5), e(6), e(5), e(4), e(3), e(1), r(),
                e(5), e(6), e(5), e(4), e(3), e(1), r(),
                q(2), q(5), h(1), q(2), q(5), h(1),
            ]),
            makeScore(title: "摇篮曲", composer: "东北民歌", tempo: 70, difficulty: .beginner, noteData: [
                // 月儿明 风儿静 树叶儿遮窗棂
                q(1), q(1), h(5), e(5), e(6), e(5), q(3), q(3), h(2), q(1), r(),
                e(5), e(5), e(3), q(3), q(2), h(1), q(6), q(5), h(3), q(2), r(),
                q(1), q(1), h(5), e(5), e(6), e(5), q(3), q(3), h(2), q(1), r(),
                e(5), e(5), e(3), q(3), q(2), h(1), q(2), q(2), h(1), q(1), r(),
                // 蛐蛐儿叫铮铮 好比那琴弦儿声
                q(3), q(3), h(5), q(6), q(5), h(3), q(5), q(3), h(2), q(1), r(),
                e(5), e(5), e(3), q(3), q(2), h(1), q(6), q(5), h(3), q(2), r(),
                q(1), q(1), h(5), e(5), e(6), e(5), q(3), q(3), h(2), q(1), r(),
                e(5), e(5), e(3), q(3), q(2), h(1), q(2), q(2), h(1), q(1), r(),
            ]),
            makeScore(title: "田园春色", composer: "陈振铎", tempo: 90, difficulty: .beginner, noteData: [
                q(5), q(6), q(5), q(6), q(5), q(3), q(2), q(3),
                q(5), q(6), qH(1), q(2), q(3), q(2), q(3), q(5),
                q(6), q(5), q(3), q(2), q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3), q(2), q(3), q(5), q(6),
                qH(1), r(), r(), r(),
                q(5), q(6), q(5), q(3), q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(2), q(3), q(5), q(3), q(5), q(6),
                qH(1), q(2), qH(1), qL(6), q(5), q(6), q(5), q(3),
                q(2), q(3), q(5), q(6), qH(1), r(), r(), r(),
            ]),
            makeScore(title: "我爱北京天安门", composer: "金月苓", tempo: 100, difficulty: .beginner, noteData: [
                q(5), qH(1), q(5), q(3), q(2), q(3), q(2), q(1),
                q(5), qH(1), q(5), q(3), q(2), q(3), q(2), q(1),
                e(5), e(6), e(5), e(3), qH(1), q(3), e(5), e(6),
                q(5), q(3), q(2), q(3), qH(1), r(), r(), r(),
                q(5), qH(1), q(5), q(3), q(2), q(3), q(2), q(1),
                q(5), qH(1), q(5), q(3), q(2), q(3), q(2), q(1),
                e(5), e(6), e(5), e(3), qH(1), q(3), e(5), e(6),
                q(5), q(3), q(2), q(3), qH(1), r(), r(), r(),
            ]),
            makeScore(title: "绣金匾", composer: "陕北民歌", tempo: 80, difficulty: .beginner, noteData: [
                e(5), e(5), e(6), eH(1), q(6), q(5), q(3), r(),
                q(2), q(3), q(2), q(1), qL(6), q(5), q(3), r(),
                e(5), e(5), e(6), eH(1), q(6), q(5), q(3), r(),
                q(2), q(3), q(2), q(1), qL(6), q(5), q(6), r(),
                qH(1), r(), r(), r(),
                q(5), q(6), qH(1), q(2), q(3), q(5), q(3), q(2),
                qH(1), q(2), q(3), q(5), q(2), qH(1), qL(6), r(),
                e(5), e(5), e(6), eH(1), q(6), q(5), q(3), r(),
                q(2), q(3), q(2), q(1), qL(6), q(5), q(6), r(),
                qH(1), r(), r(), r(),
            ]),
            makeScore(title: "八月桂花遍地开", composer: "江西民歌", tempo: 100, difficulty: .beginner, noteData: [
                q(5), q(6), qH(1), q(6), q(5), q(6), q(5), q(3),
                e(5), e(6), eH(1), e(6), q(5), r(), r(), r(),
                q(5), q(6), qH(1), q(2), q(6), q(5), q(3), r(),
                q(2), q(3), q(2), q(1), q(2), r(), r(), r(),
                q(5), q(6), qH(1), q(6), q(5), q(6), q(5), q(3),
                e(5), e(6), eH(1), e(2), q(6), q(5), q(3), r(),
                q(2), q(3), q(2), q(1), q(2), q(3), q(2), q(1),
                qL(6), q(5), q(6), qH(1), q(5), r(), r(), r(),
            ]),
            makeScore(title: "南泥湾", composer: "马可", tempo: 85, difficulty: .beginner, noteData: [
                e(5), e(5), e(6), eH(1), q(3), q(2), q(1), r(),
                qL(6), qH(1), qL(6), q(5), q(3), r(), r(), r(),
                e(5), e(5), e(6), eH(1), q(3), q(2), q(1), r(),
                qL(6), qH(1), qL(6), q(5), q(3), r(), r(), r(),
                qH(1), qH(1), qL(6), qH(1), q(3), q(2), q(3), r(),
                qL(6), q(5), q(3), q(2), q(1), r(), r(), r(),
                e(5), e(5), e(6), eH(1), q(3), q(2), q(1), r(),
                qL(6), q(5), q(3), q(2), q(1), r(), r(), r(),
            ]),
            makeDemoScore(),
        ]
        return scores
    }

    private func levelElementary() -> [Score] {
        [
            makeScore(title: "茉莉花", composer: "江苏民歌", tempo: 80, difficulty: .elementary, noteData: [
                // 好一朵茉莉花，好一朵茉莉花
                e(5), e(5), e(6), eH(1), q(6), q(5),
                e(5), e(5), e(6), eH(1), q(6), q(5),
                // 满园花开香也香不过它
                q(6), qH(1), q(3), q(2), q(3), r(2.0),
                q(6), qH(1), q(3), q(2), q(3), r(2.0),
                // 我有心采一朵戴
                e(5), e(6), e(5), e(3), e(2), e(3), e(5), e(3), q(2),
                // 又怕看花的人儿骂
                q(3), q(2), q(1), q(3), q(2), q(1), r(2.0),
                q(3), q(2), q(1), q(3), q(2), q(1), r(2.0),
                qH(1), q(2), q(3), q(2), q(1), r(2.0),
                // 好一朵茉莉花，好一朵茉莉花
                qL(6), qH(1), q(5), qL(6), qH(1), q(5),
                q(3), q(2), q(3), q(5), q(3), q(2), r(2.0),
                qH(1), q(3), q(2), qH(1), r(2.0),
                qH(1), q(3), q(2), qH(1), r(2.0),
            ]),
            makeScore(title: "小花鼓", composer: "刘北茂", tempo: 110, difficulty: .elementary, noteData: [
                q(3), q(3), q(5), q(3), q(2), q(3), q(5), q(6),
                q(3), q(3), q(5), q(3), q(2), q(3), q(5), q(6),
                q(5), q(5), q(6), q(5), q(3), q(5), q(3), q(2),
                q(1), q(2), q(1), qL(6), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), q(5), q(6), qH(1),
                q(5), r(), r(), r(),
                q(3), q(3), q(5), q(3), q(2), q(3), q(5), q(6),
                q(3), q(3), q(5), q(3), q(2), q(3), q(5), q(6),
                q(5), q(5), q(6), q(5), q(3), q(5), q(3), q(2),
                q(1), q(2), q(1), qL(6), q(5), q(6), q(5), q(3),
                q(2), q(3), q(5), q(6), q(3), q(2), q(1), q(2),
                q(1), r(), r(), r(),
            ]),
            makeScore(title: "采茶扑蝶", composer: "福建民歌", tempo: 105, difficulty: .elementary, noteData: [
                qL(6), q(5), qL(6), q(5), qL(6), qH(1), qL(6), q(5),
                q(3), q(5), qL(6), q(5), q(3), q(2), q(1), q(2),
                qL(6), q(5), qL(6), q(5), qL(6), qH(1), qL(6), q(5),
                q(3), q(5), qL(6), q(5), q(3), q(2), q(1), q(2),
                e(5), e(6), e(5), e(3), q(2), q(3), q(2), q(1),
                q(2), q(3), q(2), q(1), qL(6), q(5), q(6), qH(1),
                q(5), r(), r(), r(),
                qL(6), q(5), qL(6), q(5), qL(6), qH(1), qL(6), q(5),
                q(3), q(5), qL(6), q(5), q(3), q(2), h(1),
            ]),
            makeScore(title: "金蛇狂舞", composer: "聂耳", tempo: 130, difficulty: .elementary, noteData: [
                e(5), e(6), e(5), e(6), e(5), e(3), e(5), r(),
                eH(1), e(2), eH(1), e(2), e(5), e(6), e(5), r(),
                e(5), e(6), e(5), e(6), e(5), e(3), e(5), r(),
                eH(1), e(2), eH(1), e(2), e(5), e(6), eH(1), r(),
                e(5), e(6), e(5), e(6), e(5), e(3), e(5), r(),
                eH(1), e(2), eH(1), e(2), e(5), e(6), e(5), r(),
                e(5), e(6), eH(1), e(2), q(3), q(2), q(3), q(5),
                e(6), e(5), e(6), eH(1), q(2), r(), r(), r(),
                e(5), e(6), eH(1), e(2), q(3), q(2), q(3), q(5),
                e(6), e(5), e(6), eH(1), q(2), q(1), q(2), q(3),
                q(2), q(1), q(2), q(3), e(5), e(3), e(5), e(6),
                qH(1), r(), r(), r(),
            ]),
            makeScore(title: "翻身歌", composer: "张撷诚", tempo: 95, difficulty: .elementary, noteData: [
                q(3), q(5), q(6), qH(1), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), qH(1), q(5), r(),
                q(3), q(5), q(6), qH(1), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), qH(1), q(5), r(),
                qH(1), qH(1), qL(6), qH(1), q(3), q(5), q(3), q(2),
                qH(1), q(2), q(3), q(5), q(2), qH(1), qL(6), r(),
                qH(1), qH(1), qL(6), qH(1), q(3), q(5), q(3), q(2),
                qH(1), q(2), q(3), q(5), q(2), qH(1), qL(6), r(),
                qH(1), q(2), q(3), q(5), q(6), q(5), q(6), qH(1),
                q(5), r(), r(), r(),
                q(3), q(5), q(6), qH(1), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), qH(1), q(5), r(),
                qH(1), r(), r(), r(),
            ]),
        ]
    }

    private func levelIntermediate() -> [Score] {
        [
            makeScore(title: "赛马", composer: "黄海怀", tempo: 150, difficulty: .intermediate, noteData: [
                q(3), q(3), q(5), q(6), q(6), q(5), q(3), q(3), q(5), q(6), q(6), q(5),
                q(1), q(1), q(2), q(3), q(3), q(2), q(1), q(1), q(2), q(3), q(3), q(2),
                q(5), q(5), q(3), q(2), q(2), q(1), q(5), q(5), q(3), q(2), q(2), q(1),
                qL(6), qL(6), q(5), q(3), q(3), q(2), q(1), q(1), q(2), q(3), q(3), q(5),
                q(6), q(6), q(5), q(3), q(3), q(5), q(6), q(6), qH(1), q(2), q(2), q(1),
                qL(6), qL(6), q(5), q(3), q(3), q(5), q(6), q(6), q(5), q(3), q(3), q(5),
                q(1), q(1), q(2), q(3), q(3), q(2), q(1), q(1), q(2), q(3), q(3), q(2),
                q(5), q(5), q(3), q(2), q(2), q(1), q(5), q(5), q(3), q(2), q(2), q(1),
                qL(6), qL(6), q(5), q(3), q(3), q(2), q(1), q(1), q(2), q(3), q(3), q(5),
                q(6), q(6), q(5), q(3), q(3), q(5), q(6), q(6), qH(1), q(2), q(2), q(1),
            ]),
            makeScore(title: "良宵", composer: "刘天华", tempo: 80, difficulty: .intermediate, noteData: [
                q(3), q(3), q(5), q(6), qH(1), q(6), q(5), q(3), q(5), q(6), q(5), q(3),
                q(2), q(3), q(5), q(6), q(5), q(3), q(2), qH(1), q(2), q(3), r(),
                q(5), q(6), qH(1), q(2), qH(1), qL(6), q(5), q(3), q(2), q(1), r(),
                q(5), q(5), q(6), qH(1), q(2), qH(1), qL(6), q(5), q(3), q(5), r(),
                q(3), q(2), q(3), q(5), q(6), q(5), q(3), q(2), qH(1), q(2), qH(1), q(2),
                q(3), q(5), q(6), qH(1), q(2), qH(1), qL(6), q(5), q(3), q(5), q(6), q(5),
                q(3), q(2), q(3), q(5), q(6), q(5), q(3), q(2), qH(1), q(2), qH(1), q(2),
                q(3), q(5), q(6), qH(1), qL(6), q(5), q(3), q(2), qH(1), q(1), r(),
            ]),
            makeScore(title: "光明行", composer: "刘天华", tempo: 120, difficulty: .intermediate, noteData: [
                q(1), q(1), q(1), q(3), q(3), q(3), q(5), q(5), q(5), q(6), q(6), q(6),
                qH(1), qH(1), qH(1), q(3), q(3), q(3), q(5), q(5), q(5), q(6), q(6), q(6),
                e(5), e(6), e(5), e(3), q(2), q(3), q(2), q(1),
                e(5), e(6), e(5), e(3), q(2), q(3), q(2), q(1),
                q(2), qH(1), q(2), q(3), q(5), q(3), q(5), q(6),
                qH(1), qL(6), qH(1), q(2), q(3), q(2), q(3), q(5),
                q(6), qH(1), qL(6), q(5), q(6), qH(1), qL(6), q(5),
                q(3), q(5), q(3), q(2), q(3), q(5), q(3), q(2),
                q(1), q(2), q(1), qL(6), q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), q(2), q(3), q(2), q(1),
                h(1),
            ]),
            makeScore(title: "月夜", composer: "刘天华", tempo: 70, difficulty: .intermediate, noteData: [
                q(5), q(5), q(6), qH(1), q(2), q(3), q(5), q(3), q(2), qH(1), qL(6), q(5),
                q(3), q(5), q(6), qH(1), qL(6), q(5), q(3), q(2), q(3), q(5), r(),
                q(5), q(6), qH(1), q(2), q(3), q(2), qH(1), qL(6), q(5), q(3), r(),
                q(2), q(3), q(5), q(6), qH(1), qL(6), q(5), q(3), q(2), q(1), r(),
                q(1), q(2), q(3), q(5), q(6), q(5), q(3), q(2), q(1), qL(6), r(),
                q(5), q(6), qH(1), q(2), qH(1), qL(6), q(5), q(3), q(2), q(1), r(),
                q(5), q(5), q(6), qH(1), q(2), q(3), q(5), q(3), q(2), qH(1), qL(6), q(5),
                q(3), q(5), q(6), qH(1), qL(6), q(5), q(3), q(2), h(1),
            ]),
            makeScore(title: "喜送公粮", composer: "顾武祥、孟津津", tempo: 110, difficulty: .intermediate, noteData: [
                e(5), e(6), e(5), e(3), q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), q(6), qH(1), r(), r(), r(),
                e(5), e(6), e(5), e(3), q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), q(6), qH(1), r(), r(), r(),
                q(3), q(2), q(3), q(5), q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3), q(5), r(), r(), r(),
                e(5), e(6), e(5), e(3), q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), q(6), qH(1), r(), r(), r(),
                qL(6), qH(1), qL(6), q(5), q(3), q(5), q(3), q(2),
                qH(1), q(2), q(3), q(5), q(2), qH(1), qL(6), q(5),
                qH(1), r(), r(), r(),
            ]),
            makeScore(title: "山丹丹花开红艳艳", composer: "刘烽", tempo: 80, difficulty: .intermediate, noteData: [
                q(2), q(2), h(3), q(5), q(5), h(6),
                q(2), q(3), q(2), q(1), qL(6), q(5), q(6), r(),
                q(2), q(2), h(3), q(5), q(5), h(6),
                q(2), q(3), q(2), q(1), qL(6), q(5), q(6), r(),
                q(5), q(5), h(3), q(2), q(3), q(2), q(1), qL(6), q(5), q(6), qH(1),
                q(2), r(), r(), r(),
                q(5), q(5), h(3), q(2), q(3), q(2), q(1), qL(6), q(5), q(6), qH(1),
                q(2), r(), r(), r(),
                q(3), q(2), q(3), q(5), q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3), q(5), r(), r(), r(),
                q(5), q(5), h(6), q(2), q(3), q(2), q(1), qL(6), q(5), q(6), qH(1),
                q(2), r(), r(), r(),
            ]),
            makeScore(title: "北京有个金太阳", composer: "藏族民歌", tempo: 100, difficulty: .intermediate, noteData: [
                e(5), e(6), eH(1), e(6), q(5), q(6), q(5), q(3),
                e(5), e(6), eH(1), e(6), q(5), q(3), q(2), q(1),
                e(5), e(6), eH(1), e(6), q(5), q(6), q(5), q(3),
                e(5), e(6), eH(1), e(6), q(5), q(3), q(2), q(1),
                q(3), q(5), q(3), q(2), q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3), q(2), q(3), q(2), q(1),
                q(3), q(5), q(3), q(2), q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3), q(2), q(3), q(2), q(1),
                qH(1), q(2), q(3), q(5), q(6), q(5), q(6), qH(1),
                q(5), r(), r(), r(),
                e(5), e(6), eH(1), e(6), q(5), q(6), q(5), q(3),
                e(5), e(6), eH(1), e(6), q(5), q(3), q(2), q(1),
                qH(1), r(), r(), r(),
            ]),
            makeScore(title: "花欢乐", composer: "民间乐曲", tempo: 85, difficulty: .intermediate, noteData: [
                q(3), q(5), q(3), q(2), q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3), q(2), q(3), q(2), q(1),
                q(3), q(5), q(3), q(2), q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3), q(2), q(3), q(2), q(1),
                qL(6), qH(1), qL(6), q(5), q(3), q(5), q(3), q(2),
                q(1), q(2), q(3), q(5), q(2), qH(1), qL(6), q(5),
                q(1), r(), r(), r(),
                q(3), q(5), q(3), q(2), q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3), q(2), q(3), q(2), q(1),
                qL(6), qH(1), qL(6), q(5), q(3), q(5), q(3), q(2),
                q(1), q(2), q(3), q(5), q(2), q(3), q(2), q(1),
                qL(6), q(5), q(6), qH(1), q(5), r(), r(), r(),
            ]),
            makeScore(title: "豫北叙事曲", composer: "刘文金", tempo: 75, difficulty: .intermediate, noteData: [
                q(3), q(3), q(2), r(), q(1), q(2), q(3), q(5),
                q(6), q(5), q(6), qH(1), q(5), r(), r(), r(),
                q(5), q(5), q(6), r(), qH(1), q(2), qL(6), q(5),
                q(3), q(2), q(3), q(5), q(2), r(), r(), r(),
                q(3), q(5), q(6), qH(1), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), qH(1), q(5), q(6),
                qH(1), q(2), q(3), q(5), q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3), q(5), r(), r(), r(),
                q(5), q(6), q(5), q(3), q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), q(6), qH(1), r(), r(), r(),
                q(3), q(2), q(3), q(5), q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3), q(5), r(), r(), r(),
            ]),
            makeScore(title: "江南春色", composer: "朱昌耀", tempo: 85, difficulty: .intermediate, noteData: [
                q(3), q(5), q(6), qH(1), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), qH(1), q(5), q(6),
                qH(1), r(), r(), r(),
                q(3), q(5), q(6), qH(1), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), qH(1), q(5), q(6),
                qH(1), r(), r(), r(),
                qL(6), qH(1), qL(6), q(5), q(3), q(5), q(3), q(2),
                qH(1), q(2), q(3), q(5), q(2), qH(1), qL(6), q(5),
                qH(1), r(), r(), r(),
                q(3), q(5), q(6), qH(1), q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1), qL(6), qH(1), q(5), q(6),
                qH(1), r(), r(), r(),
                q(3), q(5), q(6), qH(1), q(2), q(3), q(2), q(1),
                qL(6), q(5), q(6), qH(1), q(5), r(), r(), r(),
                qL(6), qH(1), qL(6), q(5), q(3), q(5), q(3), q(2),
                qH(1), q(2), q(3), q(5), q(2), q(3), q(2), q(1),
                qL(6), q(5), q(6), qH(1), q(5), r(), r(), r(),
                qH(1), r(), r(), r(),
            ]),
        ]
    }

    private func levelAdvanced1() -> [Score] {
        [
            // MARK: 二泉映月 - 阿炳 (60 BPM)
            // 4/4, 低音主题开场, 中音区展开, 高潮至高音区
            makeScore(title: "二泉映月", composer: "阿炳", tempo: 60, difficulty: .advanced, noteData: [
                // Section 1 - 第一主题
                qL(6), qL(5), qL(6), q(1),
                q(2), q(3), q(5), q(6),
                q(5), q(3), q(2), q(3),
                q(5), q(6), q(5), q(3),
                q(2), q(1), qL(6), qL(5),
                qL(6), qH(1), r(), r(),
                // Section 2 - 间奏
                q(2), q(3), q(5), q(6),
                q(5), q(3), q(2), q(3),
                q(2), q(1), r(), r(),
                // Section 3 - 过渡
                q(5), q(6), qH(1), q(2),
                q(3), q(2), qH(1), qL(6),
                q(5), q(3), r(), r(),
                // Section 4 - 第一次变奏 (重复Section 1)
                qL(6), qL(5), qL(6), q(1),
                q(2), q(3), q(5), q(6),
                q(5), q(3), q(2), q(3),
                q(5), q(6), q(5), q(3),
                q(2), q(1), qL(6), qL(5),
                qL(6), qH(1), r(), r(),
                // Section 5 - 间奏重复
                q(2), q(3), q(5), q(6),
                q(5), q(3), q(2), q(3),
                q(2), q(1), r(), r(),
                // Section 6 - 过渡重复
                q(5), q(6), qH(1), q(2),
                q(3), q(2), qH(1), qL(6),
                q(5), q(3), r(), r(),
                // Section 7 - 第二次变奏 (主题再现)
                qL(6), qL(5), qL(6), q(1),
                q(2), q(3), q(5), q(6),
                q(5), q(3), q(2), q(3),
                q(5), q(6), q(5), q(3),
                q(2), q(1), qL(6), qL(5),
                qL(6), qH(1), r(), r(),
            ]),

            // MARK: 空山鸟语 - 刘天华 (90 BPM)
            // 快速模拟鸟鸣, 大量八分音符+高音区模仿鸟叫
            makeScore(title: "空山鸟语", composer: "刘天华", tempo: 90, difficulty: .advanced, noteData: [
                // 引子 - 快速音型模仿鸟鸣
                q(1), q(2), q(3), q(5),
                q(3), q(2), q(1), q(2),
                q(3), q(5), q(3), q(2),
                q(1), r(), r(), r(),
                // 第一段
                q(1), q(2), q(3), q(5),
                q(6), q(5), q(3), q(2),
                q(1), q(3), q(5), q(3),
                q(2), q(1), q(2), r(),
                q(3), q(5), q(3), q(2),
                q(1), q(2), q(1), qL(6),
                q(1), q(2), q(3), q(2),
                q(1), qL(6), q(1), r(),
                q(2), q(3), q(2), q(5),
                q(3), q(5), q(6), qH(1),
                q(6), q(5), q(3), q(5),
                q(6), qH(1), q(6), r(),
                // 第二段 - 快速上行
                q(1), q(2), q(3), q(5),
                q(6), q(5), q(3), q(2),
                q(1), q(2), q(3), q(2),
                q(1), qL(6), q(1), r(),
                q(2), q(3), q(2), q(1),
                qL(6), q(1), q(2), q(3),
                q(2), q(1), qL(6), q(5),
                q(3), q(2), q(1), r(),
            ]),

            // MARK: 江河水 - 东北民间 (50 BPM)
            // 慢速悲凉, 大量二分/附点音符拉长旋律
            makeScore(title: "江河水", composer: "东北民间", tempo: 50, difficulty: .advanced, noteData: [
                // 引子 - 双音开头
                h(1), qL(6), q(5), qL(6),
                q(1), q(2), q(3), q(5),
                q(3), q(2), q(1), qL(6),
                q(5), qL(6), q(1), qL(6),
                q(5), q(3), q(2), q(1),
                r(2.0),
                // 第二句
                q(3), q(5), q(6), qH(1),
                q(6), q(5), q(3), q(2),
                q(3), h(5),
                // 第三句
                q(3), q(2), q(1), qL(6),
                q(5), qL(6), q(1), q(2),
                q(3), q(5), q(3), q(2),
                q(1), qL(6), q(5), qL(6),
                q(1), qL(6), q(5), q(3),
                q(2), q(1), r(2.0),
                // 第四句
                q(5), q(6), qH(1), q(2),
                q(3), q(2), q(1), qL(6),
                q(5), r(), r(), r(),
                // 第五句 - 高潮
                qL(6), q(5), qL(6), q(1),
                q(2), q(3), q(5), q(6),
                q(5), q(3), q(2), q(1),
                q(2), q(3), q(2), q(1),
                qL(6), q(5), qL(6), q(1),
                qL(6), q(5), q(3), q(2),
                q(1), qL(6), q(5), qL(6),
                q(1), qL(6), q(5), q(3),
                q(2), q(1), r(2.0),
            ]),

            // MARK: 三门峡畅想曲 - 刘文金 (130 BPM)
            // 快速激昂, 十六分/八分音符为主
            makeScore(title: "三门峡畅想曲", composer: "刘文金", tempo: 130, difficulty: .advanced, noteData: [
                // 第一段
                e(5), e(6), eH(1), e(2),
                e(3), e(5), e(6), eH(1),
                e(2), q(3), r(), r(),
                // 第二句
                e(2), eH(1), e(6), e(5),
                e(3), e(2), eH(1), e(6),
                e(5), q(3), r(), r(),
                // 重复第一句
                e(5), e(6), eH(1), e(2),
                e(3), e(5), e(6), eH(1),
                e(2), q(3), r(), r(),
                // 重复第二句
                e(2), eH(1), e(6), e(5),
                e(3), e(2), eH(1), e(6),
                e(5), q(3), r(), r(),
                // 过渡段
                e(6), e(5), e(3), e(2),
                e(3), e(5), e(6), e(5),
                e(3), q(2), r(), r(),
                // 展开
                e(1), e(2), e(3), e(5),
                e(3), e(2), eH(1), e(6),
                e(5), q(6), r(), r(),
                // 主题再现
                e(5), e(6), eH(1), e(2),
                e(3), e(5), e(6), eH(1),
                e(2), q(3), r(), r(),
                e(2), eH(1), e(6), e(5),
                e(3), e(2), eH(1), e(6),
                e(5), q(3), r(), r(),
                // 结尾
                e(5), e(6), eH(1), e(2),
                e(3), e(5), e(6), eH(1),
                e(2), q(3), r(), r(),
                e(2), eH(1), e(6), e(5),
                e(3), e(2), eH(1), e(6),
                q(5), r(), r(), r(),
            ]),
        ]
    }

    private func levelAdvanced2() -> [Score] {
        [
            // MARK: 病中吟 - 刘天华 (55 BPM)
            // 4/4, 缓慢沉吟, 中音区抒情, 偶尔下行至低音
            makeScore(title: "病中吟", composer: "刘天华", tempo: 55, difficulty: .advanced, noteData: [
                q(1), q(2), q(3), q(5),
                q(6), q(5), q(3), q(2),
                q(1), q(2), q(3), q(5),
                qL(6), r(), r(), r(),
                q(5), q(6), q(1), q(2),
                qL(6), q(5), q(3), q(2),
                q(3), q(2), q(1), qL(6),
                q(5), r(), r(), r(),
                q(1), q(2), q(3), q(5),
                q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3),
                q(5), r(), r(), r(),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), qL(6),
                q(1), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                qL(6), q(5), q(3), q(2),
                q(1), q(2), q(3), q(5),
                qL(6), r(), r(), r(),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), qL(6),
                q(1), r(), r(), r(),
            ]),

            // MARK: 听松 - 阿炳 (60 BPM)
            // 4/4, 刚劲有力, 中音区为主, 有跳跃
            makeScore(title: "听松", composer: "阿炳", tempo: 60, difficulty: .advanced, noteData: [
                q(1), q(5), qL(6), q(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), q(1), q(5), qL(6),
                q(1), r(), r(), r(),
                q(1), q(5), qL(6), q(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), q(1), q(5), qL(6),
                q(1), r(), r(), r(),
                // 中段
                q(3), q(2), q(3), q(5),
                q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3),
                q(5), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                q(3), q(2), q(3), q(5),
                q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3),
                q(5), r(), r(), r(),
                // 再现
                q(1), q(5), qL(6), q(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), q(1), q(5), qL(6),
                q(1), r(), r(), r(),
            ]),

            // MARK: 独弦操 - 刘天华 (65 BPM)
            // 4/4, 全曲在一根弦上演奏, 音域较窄
            makeScore(title: "独弦操", composer: "刘天华", tempo: 65, difficulty: .advanced, noteData: [
                q(1), q(2), q(3), q(5),
                q(6), qH(1), q(6), q(5),
                q(3), q(5), q(3), q(2),
                q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), q(5), q(6), qH(1),
                q(5), r(), r(), r(),
                q(1), q(2), q(3), q(5),
                q(6), qH(1), q(6), q(5),
                q(3), q(5), q(3), q(2),
                q(1), q(2), q(1), qL(6),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), q(5), q(6), qH(1),
                q(5), r(), r(), r(),
                // 发展段
                q(3), q(5), q(6), qH(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), qL(6),
                q(1), q(2), q(3), q(5),
                q(6), q(5), q(6), qH(1),
                q(5), q(3), q(2), q(3),
                q(5), r(), r(), r(),
                q(1), r(), r(), r(),
            ]),

            // MARK: 闲居吟 - 刘天华 (70 BPM)
            // 4/4, 闲适恬淡, 中音区为主, 流畅优美
            makeScore(title: "闲居吟", composer: "刘天华", tempo: 70, difficulty: .advanced, noteData: [
                q(3), q(5), q(6), qH(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), qL(6),
                q(1), r(), r(), r(),
                q(3), q(5), q(6), qH(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), qL(6),
                q(1), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                q(3), q(2), q(3), q(5),
                q(6), q(5), q(3), q(2),
                q(1), r(), r(), r(),
                q(3), q(5), q(6), qH(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), qL(6),
                q(1), r(), r(), r(),
                qL(6), qH(1), qL(6), q(5),
                q(3), q(5), q(3), q(2),
                q(1), q(2), q(3), q(5),
                q(2), q(1), qL(6), q(5),
                q(1), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                q(3), q(2), q(3), q(5),
                q(6), q(5), q(3), q(2),
                q(1), r(), r(), r(),
                q(3), q(5), q(6), qH(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), qH(1), q(5), qL(6),
                q(1), r(), r(), r(),
            ]),
        ]
    }

    private func levelAdvanced3() -> [Score] {
        [
            // MARK: 烛影摇红 - 刘天华 (75 BPM)
            // 4/4, 轻快摇曳, 中高音区交替
            makeScore(title: "烛影摇红", composer: "刘天华", tempo: 75, difficulty: .advanced, noteData: [
                q(3), q(2), q(3), q(5),
                q(6), qH(1), q(6), q(5),
                q(3), q(2), q(3), q(5),
                qL(6), r(), r(), r(),
                q(3), q(2), q(3), q(5),
                q(6), qH(1), q(6), q(5),
                q(3), q(2), q(3), q(5),
                qL(6), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                q(3), q(5), q(3), q(2),
                q(1), q(2), q(3), q(5),
                q(2), r(), r(), r(),
                q(3), q(2), q(3), q(5),
                q(6), qH(1), q(6), q(5),
                q(3), q(2), q(3), q(5),
                qL(6), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                q(3), q(5), q(3), q(2),
                q(1), q(2), qL(6), q(5),
                q(1), r(), r(), r(),
                q(3), q(2), q(3), q(5),
                q(6), qH(1), q(6), q(5),
                q(3), q(5), q(6), qH(1),
                q(5), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                q(3), q(5), q(3), q(2),
                q(1), q(2), qL(6), q(5),
                q(1), r(), r(), r(),
            ]),

            // MARK: 汉宫秋月 - 古曲 (50 BPM)
            // 4/4, 慢速哀怨, 音域宽广, 低音区深沉, 高音区凄婉
            makeScore(title: "汉宫秋月", composer: "古曲", tempo: 50, difficulty: .advanced, noteData: [
                q(2), q(3), q(5), qL(6),
                q(3), q(2), q(3), q(5),
                qL(6), q(5), q(3), q(2),
                q(1), r(), r(), r(),
                q(2), q(3), q(5), qL(6),
                q(3), q(2), q(3), q(5),
                qL(6), q(5), q(3), q(2),
                q(1), r(), r(), r(),
                q(3), q(5), q(6), qH(1),
                q(5), q(6), q(5), q(3),
                q(2), q(3), q(2), q(1),
                qL(6), q(5), qL(6), r(),
                q(1), r(), r(), r(),
                q(2), q(3), q(5), qL(6),
                q(3), q(2), q(3), q(5),
                qL(6), q(5), q(3), q(2),
                q(1), r(), r(), r(),
                q(5), q(6), qH(1), q(2),
                q(3), q(5), q(3), q(2),
                q(1), q(2), q(3), q(5),
                q(2), q(3), q(2), q(1),
                qL(6), q(5), qL(6), qH(1),
                q(5), r(), r(), r(),
                q(2), q(3), q(5), qL(6),
                q(3), q(2), q(3), q(5),
                qL(6), q(5), q(3), q(2),
                q(1), r(), r(), r(),
            ]),
        ]
    }

    /// Simple format: each note is a degree (duration=1.0, octave=0)
    private func makeScore(title: String, composer: String, tempo: Int, difficulty: Difficulty, notes: [Int]) -> Score {
        makeScore(title: title, composer: composer, tempo: tempo, difficulty: difficulty,
                  noteData: notes.map { (degree: $0, duration: 1.0, octave: 0, isDotted: false) })
    }

    /// Full format: specify degree, duration, octave, isDotted for each note
    private func makeScore(title: String, composer: String, tempo: Int, difficulty: Difficulty,
                           noteData: [(degree: Int, duration: Double, octave: Int, isDotted: Bool)]) -> Score {
        var measures: [Measure] = []
        var currentNotes: [Note] = []

        for nd in noteData {
            currentNotes.append(Note(
                degree: nd.degree,
                octave: nd.octave,
                duration: nd.duration,
                isDotted: nd.isDotted
            ))

            // Check if measure is full: 4/4 time → total duration >= 4.0
            let totalDuration = currentNotes.reduce(0) { $0 + $1.duration }
            if totalDuration >= 3.99 || currentNotes.count >= 8 {
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

    private func makeDemoScore() -> Score {
        typealias ND = (degree: Int, duration: Double, octave: Int, isDotted: Bool)
        let data: [ND] = [
            // 第1小节：基本音符（四分音符）
            (1, 1.0, 0, false), (2, 1.0, 0, false), (3, 1.0, 0, false), (4, 1.0, 0, false),
            // 第2小节：高八度音符（上方加点）
            (5, 1.0, 0, false), (6, 1.0, 0, false), (7, 1.0, 0, false), (1, 1.0, 1, false),
            // 第3小节：低八度音符（下方加点）
            (7, 1.0, 0, false), (6, 1.0, 0, false), (5, 1.0, 0, false), (1, 1.0, -1, false),
            // 第4小节：八分音符（下方一条减时线）
            (1, 0.5, 0, false), (2, 0.5, 0, false), (3, 0.5, 0, false), (4, 0.5, 0, false),
            (5, 0.5, 0, false), (6, 0.5, 0, false), (7, 0.5, 0, false), (1, 0.5, 1, false),
            // 第5小节：二分音符（右侧增时线）
            (3, 2.0, 0, false), (5, 2.0, 0, false),
            // 第6小节：附点音符 + 混合
            (5, 1.5, 0, true), (3, 0.5, 0, false), (1, 1.0, 0, false), (0, 1.0, 0, false),
            // 第7小节：高八度八分音符（上方加点+下方减时线）
            (3, 0.5, 1, false), (5, 0.5, 1, false), (6, 0.5, 1, false), (5, 0.5, 1, false),
            (3, 0.5, 1, false), (2, 0.5, 0, false), (1, 0.5, 0, false), (0, 0.5, 0, false),
            // 第8小节：附点二分音符 + 结束
            (1, 3.0, 0, true), (0, 1.0, 0, false),
        ]
        return makeScore(title: "简谱识谱示范", composer: "练习曲", tempo: 80, difficulty: .beginner, noteData: data)
    }
}
