import Foundation

/// Parses jianpu (numbered musical notation) text into a Score model.
///
/// Syntax:
///   - Numbers 1-7 = scale degrees, 0 = rest
///   - Spaces = note separator, | = bar line
///   - Dot after number = raise octave (1. = high do)
///   - Dot before number = lower octave (.1 = low do)
///   - Dash after number = half duration (5- = 2 beats)
///   - Underscore after number = double duration (5_ = 4 beats)
enum JianpuParser {

    struct ParseError: Error, LocalizedError {
        let line: Int
        let position: Int
        let message: String

        var errorDescription: String? {
            "第 \(line) 行第 \(position) 列: \(message)"
        }
    }

    /// Parse jianpu text into a Score.
    static func parse(_ text: String, title: String = "自定义曲谱") throws -> Score {
        var notes: [(Int, Int, Double)] = []
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            throw ParseError(line: 1, position: 1, message: "乐谱内容为空")
        }

        for (lineIdx, line) in lines.enumerated() {
            let lineNum = lineIdx + 1
            try parseLine(line, lineNum: lineNum, into: &notes)
        }

        var measures: [Measure] = []
        var currentMeasureNotes: [Note] = []

        for (degree, octave, duration) in notes {
            if degree == -1 { continue } // bar line marker
            let note = Note(degree: degree, octave: octave, duration: duration)
            currentMeasureNotes.append(note)
            if currentMeasureNotes.reduce(0, { $0 + $1.duration }) >= 4.0 {
                measures.append(Measure(notes: currentMeasureNotes))
                currentMeasureNotes = []
            }
        }

        if !currentMeasureNotes.isEmpty {
            measures.append(Measure(notes: currentMeasureNotes))
        }

        return Score(title: title, measures: measures)
    }

    // MARK: - Private

    private static func parseLine(_ line: String, lineNum: Int, into notes: inout [(Int, Int, Double)]) throws {
        var idx = line.startIndex

        while idx < line.endIndex {
            let ch = line[idx]

            switch ch {
            case " ", "\t":
                idx = line.index(after: idx)

            case "|":
                notes.append((-1, 0, 0))
                idx = line.index(after: idx)

            case "0"..."7":
                let result = try parseNoteToken(from: line, at: &idx, lineNum: lineNum)
                notes.append(result)

            case "#", "/":
                return

            default:
                idx = line.index(after: idx)
            }
        }
    }

    private static func parseNoteToken(from line: String, at idx: inout String.Index, lineNum: Int) throws -> (degree: Int, octave: Int, duration: Double) {
        var octaveOffset = 0
        var pos = idx
        let col = line.distance(from: line.startIndex, to: idx) + 1

        while pos < line.endIndex, line[pos] == "." {
            octaveOffset -= 1
            pos = line.index(after: pos)
        }

        guard pos < line.endIndex, let degree = Int(String(line[pos])), degree >= 0, degree <= 7 else {
            throw ParseError(line: lineNum, position: col, message: "无效音符: 需要 0-7 的数字")
        }
        pos = line.index(after: pos)

        while pos < line.endIndex, line[pos] == "." {
            octaveOffset += 1
            pos = line.index(after: pos)
        }

        var duration: Double = 1.0
        if pos < line.endIndex {
            switch line[pos] {
            case "-":
                duration = 2.0
                pos = line.index(after: pos)
            case "_":
                duration = 4.0
                pos = line.index(after: pos)
            default:
                break
            }
        }

        idx = pos
        return (degree, octaveOffset, duration)
    }
}
