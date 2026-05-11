import SwiftUI
import CoreGraphics

// MARK: - 渲染方案分析
//
// 对比 Canvas vs SVG (WKWebView)：
//
// Canvas (SwiftUI):
//  ✅ 原生 SwiftUI 集成，支持手势（onTapGesture）
//  ✅ 高性能立即模式绘制，Core Graphics 支持贝塞尔曲线
//  ✅ 状态驱动刷新，天然与 @State/@Binding 协同
//  ✅ 无 WebView 开销，内存占用低
//  ⚠️ 文本排版需要自行计算
//
// SVG via WKWebView:
//  ✅ 丰富的文本/曲线支持（<text>, <path>）
//  ✅ 可复用 Web 端简谱渲染库
//  ❌ 异步加载，白屏闪烁
//  ❌ 手势传递复杂（JS ↔ Swift 桥接）
//  ❌ WebView 内存开销大
//  ❌ 状态同步延迟
//
// 推荐：Canvas。
// 理由：简谱是单行数字+符号，文本复杂度低，Canvas 完全胜任；
// 且音乐渲染需要高帧率实时反馈（音高判断颜色），Canvas 的立即模式天然适合。

// MARK: - 间距布局算法
//
// 核心原则：音符的水平位置由其在小节内的时值权重决定。
//
// 1. 基础音符宽度（Base Unit Width）：
//    - 四分音符（duration=1.0）作为基本单位，分配宽度 noteBaseWidth
//    - 八分音符（0.5）→ 0.5×，二分音符（2.0）→ 2×，以此类推
//
// 2. 小节宽度分配：
//    - 各小节等分画布总宽度
//    - 小节内按权重分布：totalWeight = ∑ note.duration
//    - noteX = barStartX + (cumulativeWeight / totalWeight) * measureWidth
//
// 3. 弹性调整：
//    - 音符最小间距约束（minNoteSpacing），避免密集段完全挤在一起
//    - 尾部均匀化：将剩余空间平均分配到各音符之间
//
// 4. 多声部对齐：
//    - 各声部共用小节线坐标
//    - 小节线位置由所有声部中最大宽度决定
//    - 声部独立排布上下垂直堆叠

/// 绘制简谱所需的所有核心元素
/// - 音符数字（1-7）和休止符（0）
/// - 高音点/低音点（octave dots）
/// - 减时线（下方单/双/三下划线 = 八分/十六分/三十二分音符）
/// - 增时线（右侧短横线，延长时值）
/// - 附点（右侧小圆点）
/// - 小节线（单竖线）和终止线（双竖线）
struct JianpuView: View {
    let score: Score
    let currentNoteIndex: Int
    let judgments: [PitchJudger.Judgment]
    let lastAttemptJudgment: PitchJudger.Judgment?
    let onTapNote: ((Note) -> Void)?

    // MARK: - 排版常量

    private let topPadding: CGFloat = 16
    private let leftPadding: CGFloat = 16
    private let rightPadding: CGFloat = 16
    /// 四分音符基础宽度（核心间距单元）
    private let noteBaseWidth: CGFloat = 32
    /// 音符间最小间距
    private let minNoteSpacing: CGFloat = 8
    /// 数字字号
    private let numberSize: CGFloat = 24
    /// 上下点直径
    private let dotSize: CGFloat = 5
    /// 增时线宽度
    private let dashWidth: CGFloat = 12
    /// 行高（含上下间距）
    private let staffLineHeight: CGFloat = 64
    /// 音符间最小中心距（防止 24pt 字号重叠）
    private let minCenterSpacing: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width - leftPadding - rightPadding
            let contentWidth = computeContentWidth(canvasWidth: max(w, 100))
            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                Canvas { ctx, size in
                    drawScore(context: &ctx, canvasWidth: max(size.width, 100))
                }
                .frame(minWidth: contentWidth, minHeight: staffLineHeight + topPadding + 10)
                .onTapGesture { loc in
                    handleTap(at: loc, canvasWidth: max(w, contentWidth))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 绘制入口

    private func drawScore(context: inout GraphicsContext, canvasWidth: CGFloat) {
        let barXs = computeBarXPositions(measureCount: score.measures.count, canvasWidth: canvasWidth)
        let y: CGFloat = topPadding + 16  // 数字基线

        var globalNoteIdx = 0

        for measureIdx in score.measures.indices {
            let measure = score.measures[measureIdx]
            let barX = barXs[measureIdx]
            let nextBarX = (measureIdx + 1 < barXs.count) ? barXs[measureIdx + 1] : canvasWidth + leftPadding
            let measureWidth = nextBarX - barX

            // 1. 小节线（不画第一小节起始线）
            if measureIdx > 0 {
                drawBarLine(context: &context, x: barX, y: topPadding + 4, height: staffLineHeight,
                            isEndBar: false)
            }

            // 2. 计算音符位置
            let notePositions = computeNoteXPositions(measure: measure, barX: barX + 4, measureWidth: measureWidth - 8)

            // 3. 绘制歌词（如果有）

            // 4. 逐音符绘制
            for noteIdx in measure.notes.indices {
                let note = measure.notes[noteIdx]
                let posX = notePositions[noteIdx]
                defer { globalNoteIdx += 1 }

                let color = noteDisplayColor(globalIdx: globalNoteIdx)
                let isCurrent = globalNoteIdx == currentNoteIndex

                // 当前音符高亮背景
                if isCurrent {
                    context.fill(Path(roundedRect: CGRect(x: posX - 10, y: y - numberSize - 6, width: 20, height: numberSize + 12), cornerRadius: 4), with: .color(.accentColor.opacity(0.2)))
                }

                if note.isRest {
                    drawRest(context: &context, at: CGPoint(x: posX, y: y), color: color)
                    continue
                }

                // 高音点（上方）
                drawOctaveDots(context: &context, at: CGPoint(x: posX, y: y), octave: note.octave, isHigh: true)

                // 音符数字
                drawNumber(context: &context, text: note.displayText, at: CGPoint(x: posX, y: y), color: color)

                // 低音点（下方）
                drawOctaveDots(context: &context, at: CGPoint(x: posX, y: y), octave: note.octave, isHigh: false)

                // 减时线（下划线）
                let underlines = durationUnderlineCount(duration: note.duration)
                if underlines > 0 {
                    drawDurationLines(context: &context, at: CGPoint(x: posX, y: y), count: underlines, color: color)
                }

                // 增时线（右侧短横线）
                let dashes = durationDashCount(duration: note.duration)
                if dashes > 0 {
                    drawAugmentationDashes(context: &context, from: CGPoint(x: posX, y: y), count: dashes, color: color)
                }

                // 附点
                if note.isDotted {
                    drawDot(context: &context, after: CGPoint(x: posX, y: y))
                }
            }
        }

        // 终止线（双竖线）在最后一小节右侧
        if let lastBarX = barXs.last {
            drawBarLine(context: &context, x: lastBarX, y: topPadding + 4, height: staffLineHeight,
                        isEndBar: true)
        }
    }

    // MARK: - 间距计算

    /// 计算内容总宽度（各小节最小宽度之和，确保不会重叠）
    private func computeContentWidth(canvasWidth: CGFloat) -> CGFloat {
        guard !score.measures.isEmpty else { return canvasWidth }
        let totalMin = score.measures.reduce(0) { $0 + minMeasureWidth($1) }
        return max(canvasWidth, totalMin) + leftPadding + rightPadding
    }

    /// 小节最小宽度：基于音符数量和最小中心距
    private func minMeasureWidth(_ measure: Measure) -> CGFloat {
        guard !measure.notes.isEmpty else { return 40 }
        let w = (CGFloat(measure.notes.count) * minCenterSpacing) + minNoteSpacing
        return max(40, w)
    }

    /// 按小节时值权重分配画布宽度（而非等分）
    /// 每个小节获得的宽度与其音符总时值成正比
    /// 同时确保每个小节至少容纳其所有音符不重叠
    private func computeBarXPositions(measureCount: Int, canvasWidth: CGFloat) -> [CGFloat] {
        guard measureCount > 0, !score.measures.isEmpty else { return [leftPadding] }

        // 每小节的时值权重
        let weights = score.measures.map { measure in
            measure.notes.reduce(0) { $0 + max($1.duration, 0.5) }
        }
        let totalWeight = weights.reduce(0, +)

        guard totalWeight > 0 else {
            return (0...measureCount).map { CGFloat($0) * canvasWidth / CGFloat(measureCount) + leftPadding }
        }

        // 计算各小节最小宽度
        let minWidths = score.measures.map(minMeasureWidth)
        let minTotalWidth = minWidths.reduce(0, +)
        let effectiveWidth = max(canvasWidth, minTotalWidth)

        // 剩余宽度（可分配宽度）
        let extraWidth = effectiveWidth - minTotalWidth

        var positions: [CGFloat] = [leftPadding]
        var cumulative: CGFloat = 0
        var cumulativeMin: CGFloat = 0
        for i in weights.indices {
            cumulative += weights[i]
            // 按权重分配额外宽度
            let extra = extraWidth > 0 ? (weights[i] / totalWeight) * extraWidth : 0
            let barWidth = minWidths[i] + extra
            cumulativeMin += barWidth
            let x = leftPadding + cumulativeMin
            positions.append(x)
        }
        return positions
    }

    /// 时值权重定位：各音符按 duration 比例占据小节宽度
    /// 强制最小中心距 minCenterSpacing 确保不重叠
    private func computeNoteXPositions(measure: Measure, barX: CGFloat, measureWidth: CGFloat) -> [CGFloat] {
        let notes = measure.notes
        guard !notes.isEmpty else { return [] }

        let totalWeight = notes.reduce(0) { $0 + max($1.duration, 0.125) }
        guard totalWeight > 0 else {
            return notes.indices.map { barX + measureWidth * CGFloat($0 + 1) / CGFloat(notes.count + 1) }
        }

        // 计算时值比例下的理想位置
        var idealPositions: [CGFloat] = []
        var cumulativeWeight: CGFloat = 0
        for note in notes {
            let w = max(note.duration, 0.125)
            let centerX = barX + (cumulativeWeight + w / 2) / totalWeight * measureWidth
            idealPositions.append(centerX)
            cumulativeWeight += w
        }

        // 强制执行最小间距：从左到右扫描，确保每个音符与前一个相距至少 minCenterSpacing
        var positions = idealPositions
        for i in 1..<positions.count {
            let minX = positions[i - 1] + minCenterSpacing
            if positions[i] < minX {
                positions[i] = minX
            }
        }

        return positions
    }

    // MARK: - 时值视觉映射

    /// 减时线数量（八分=1，十六分=2，三十二分=3）
    private func durationUnderlineCount(duration: Double) -> Int {
        if duration <= 0.125 { return 3 }
        if duration <= 0.25 { return 2 }
        if duration <= 0.5 { return 1 }
        return 0
    }

    /// 增时线数量（超过一拍的每拍一条横线）
    private func durationDashCount(duration: Double) -> Int {
        guard duration > 1.0 else { return 0 }
        // 附点音符：duration 已含附点时值，但附点本身用 dot 表示
        // 增时线 = 整数拍数 - 1（纯整数部分）
        return Int(floor(duration)) - 1
    }

    // MARK: - 绘制原语

    /// 小节线
    private func drawBarLine(context: inout GraphicsContext, x: CGFloat, y: CGFloat, height: CGFloat, isEndBar: Bool) {
        if isEndBar {
            // 终止线：双竖线
            var p1 = Path()
            p1.move(to: CGPoint(x: x, y: y))
            p1.addLine(to: CGPoint(x: x, y: y + height))
            context.stroke(p1, with: .color(.primary), lineWidth: 1.5)

            var p2 = Path()
            let x2 = x + 5
            p2.move(to: CGPoint(x: x2, y: y))
            p2.addLine(to: CGPoint(x: x2, y: y + height))
            context.stroke(p2, with: .color(.primary), lineWidth: 2.5)
        } else {
            // 普通小节线
            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + height))
            context.stroke(p, with: .color(.primary), lineWidth: 1)
        }
    }

    /// 音符数字
    private func drawNumber(context: inout GraphicsContext, text: String, at point: CGPoint, color: Color) {
        context.draw(Text(text).font(.system(size: numberSize, weight: .bold)).foregroundColor(color),
                     at: CGPoint(x: point.x, y: point.y))
    }

    /// 休止符
    private func drawRest(context: inout GraphicsContext, at point: CGPoint, color: Color) {
        context.draw(Text("0").font(.system(size: numberSize, weight: .bold)).foregroundColor(color),
                     at: CGPoint(x: point.x, y: point.y))
    }

    /// 高音 / 低音点
    /// 高音：数字上方 octave 个点
    /// 低音：数字下方 |octave| 个点
    private func drawOctaveDots(context: inout GraphicsContext, at point: CGPoint, octave: Int, isHigh: Bool) {
        let count = isHigh ? max(octave, 0) : max(-octave, 0)
        guard count > 0 else { return }

        let dotSpacing: CGFloat = dotSize + 2
        let yOffset: CGFloat = isHigh ? -numberSize * 0.5 - 4 : numberSize * 0.5 + 4
        let startX = point.x - (CGFloat(count - 1) * dotSpacing) / 2

        for i in 0..<count {
            let dotRect = CGRect(x: startX + CGFloat(i) * dotSpacing,
                                 y: point.y + yOffset,
                                 width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: dotRect), with: .color(.primary))
        }
    }

    /// 减时线（下划线）
    private func drawDurationLines(context: inout GraphicsContext, at point: CGPoint, count: Int, color: Color) {
        let lineWidth: CGFloat = 12
        let lineSpacing: CGFloat = 4
        let startY = point.y + numberSize * 0.5 + 4

        for i in 0..<count {
            let y = startY + CGFloat(i) * lineSpacing
            var p = Path()
            p.move(to: CGPoint(x: point.x - lineWidth / 2, y: y))
            p.addLine(to: CGPoint(x: point.x + lineWidth / 2, y: y))
            context.stroke(p, with: .color(color), lineWidth: 1.5)
        }
    }

    /// 增时线（右侧短横线）
    private func drawAugmentationDashes(context: inout GraphicsContext, from point: CGPoint, count: Int, color: Color) {
        let gap: CGFloat = 2
        let startX = point.x + numberSize * 0.35 + gap
        let y = point.y
        for i in 0..<count {
            let x = startX + CGFloat(i) * (dashWidth + gap)
            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x + dashWidth, y: y))
            context.stroke(p, with: .color(color), lineWidth: 2)
        }
    }

    /// 附点
    private func drawDot(context: inout GraphicsContext, after point: CGPoint) {
        let dotX = point.x + numberSize * 0.35 + 4
        let dotRect = CGRect(x: dotX, y: point.y - dotSize * 0.5 + 4, width: dotSize, height: dotSize)
        context.fill(Path(ellipseIn: dotRect), with: .color(.primary))
    }

    // MARK: - 颜色判断

    private func effectiveJudgment(globalIdx: Int) -> PitchJudger.Judgment? {
        if globalIdx == currentNoteIndex, let last = lastAttemptJudgment {
            return last
        }
        guard globalIdx < judgments.count else { return nil }
        return judgments[globalIdx]
    }

    private func noteDisplayColor(globalIdx: Int) -> Color {
        guard let j = effectiveJudgment(globalIdx: globalIdx) else { return .primary }
        if j.isCorrect { return .green }
        if abs(j.centsOff) > PitchJudger.centTolerance { return .red }
        return .orange
    }

    // MARK: - 点击处理

    private func handleTap(at location: CGPoint, canvasWidth: CGFloat) {
        // 与绘制逻辑相同的布局计算
        let barXs = computeBarXPositions(measureCount: score.measures.count, canvasWidth: canvasWidth)
        var globalNoteIdx = 0

        for measureIdx in score.measures.indices {
            let measure = score.measures[measureIdx]
            let barX = barXs[measureIdx]
            let nextBarX = (measureIdx + 1 < barXs.count) ? barXs[measureIdx + 1] : canvasWidth + leftPadding
            let measureWidth = nextBarX - barX
            let notePositions = computeNoteXPositions(measure: measure, barX: barX + 4, measureWidth: measureWidth - 8)

            for noteIdx in measure.notes.indices {
                let note = measure.notes[noteIdx]
                defer { globalNoteIdx += 1 }

                let posX = notePositions[safe: noteIdx] ?? barX
                let hitRect = CGRect(x: posX - 12, y: topPadding + 8, width: 24, height: 40)
                if hitRect.contains(location) {
                    onTapNote?(note)
                    return
                }
            }
        }
    }
}

// MARK: - Safe array access helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
