#  Erhu Trainer

[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-18.0+-000000?logo=apple)](https://developer.apple.com/ios)
[![License](https://img.shields.io/badge/license-MIT-blue)](#license)

**智能二胡陪练 — 实时音高检测 · 简谱显示 · CD 品质样本试听**

> 为每一位想要精准练琴的学习者打造，让音准反馈触手可及。

---

## 概述

盼盼学二胡将传统民乐练习与现代音频 DSP 融合。App 通过麦克风实时采集演奏，运行 YIN 音高检测算法，将每个音符与乐谱对比，输出音分精度的即时反馈。内置试听引擎使用 **43 个从专业录音中提取的 CD 品质单音样本** 播放曲谱，让学习者在演奏前先听到纯正音色。

---

## 功能

### 🎵 简谱渲染
基于 Canvas 的数字简谱引擎，支持高低八度标记、小节线、装饰音 — 纯 SwiftUI 实现，无第三方依赖。

### 🎯 实时音高检测
- **YIN 算法**（de Cheveigné & Kawahara, 2002）配合亚采样抛物线插值
- 针对二胡泛音特性定制的倍频错误校正
- 滑音平滑处理 — 40 ms 稳定性门控，避免演奏滑音时误触发
- 检测范围：D3 (146 Hz) – A6 (1760 Hz)，覆盖二胡完整音域

### 🔊 样本试听
- **43 个 WAV 样本** 从 466 MB CD 品质录音中离线提取 — C4 到 Bb5 每个半音一个
- 轮询样本选择 + 30 ms 淡入淡出包络，音色过渡自然
- 音域外音符自动就近匹配变调（< 100 cents），保持音色一致
- *赛马* 全曲高品质独立播放

### 📊 音准评分
- 音分偏差实时显示（±0–30 cents = 准）
- 单次练习准确率与平均偏差统计
- 视觉反馈：正确音符绿色高亮，错音红色闪烁，演奏光标实时同步

### 📚 内置曲库
经典二胡曲目：赛马、二泉映月、良宵等，每首带有速度标记和完整简谱数据。

---

## 项目架构

```
ErhuApp/
├── Audio/
│   ├── AudioEngine.swift       # YIN 音高检测 + AVAudioEngine 输入
│   ├── ErhuSamplePlayer.swift  # 样本库加载与 WAV 播放
│   ├── NotePlayer.swift        # 加法合成回退方案
│   └── Metronome.swift         # 节拍器
├── Models/                     # 数据模型
├── Services/
│   ├── PitchJudger.swift       # 频率→音符比较与评分
│   ├── ScoreService.swift      # 曲库 CRUD
│   ├── RecordingService.swift  # 练习记录持久化 + Core Data
│   └── JianpuParser.swift      # 纯文本简谱解析
├── Views/                      # 13 个 SwiftUI 界面
└── Resources/
    ├── Notes/                  # 43 个单音 WAV 样本
    └── 赛马完整录音.mp3
```

### DSP 流水线

```
麦克风 → [RMS 噪声门] → [YIN 自相关] → [抛物线插值]
  → [滑音平滑] → [频率 → 音符/八度/音分偏差]
  → PitchJudger.compare(目标音符) → Judgment { isCorrect, centsOff }
```

---

## 快速开始

### 环境要求
- Xcode 16.0+
- iOS 18.0+ 模拟器或真机

### 构建运行

```bash
git clone https://github.com/maochendong/erhuApp.git
cd erhuApp
xcodebuild -scheme ErhuApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

或在 Xcode 中打开 `ErhuApp.xcodeproj` 按 **⌘R**。

---

## 技术要点

| 模块 | 技术方案 | 选型理由 |
|------|----------|----------|
| 音高检测 | YIN + 抛物线插值 | 亚音分精度，O(n) 时间复杂度 |
| 倍频校正 | 多候选 CMND 谷底评分 | 二胡强二次泛音会误导单一最小值搜索 |
| 滑音处理 | 40 cents 稳定性门控 × 80 ms 窗口 | 保留自然滑音，避免检测碎片化 |
| 音频预览 | 逐音符样本 + AVAudioUnitTimePitch 变调 | 保留真实音色，远优于合成音 |
| 样本提取 | RMS 分割 → 自相关标记 → 音名标注 | 从 46 min 录音得到 43 个干净样本 |
| 简谱显示 | Canvas 自定义排版引擎 | 完全掌控简谱排版规范 |

---

## 样本提取流程

配套脚本 `scripts/extract_erhu_samples.py` 将 466 MB / 46 分钟的 CD 录音处理为独立单音 WAV：

1. **RMS 分割** — 2048 样本滑动窗口，检测起止边界
2. **音高检测** — 每段自相关分析 → 标记最近半音
3. **质量筛选** — 剔除音高不稳或噪声过多的片段
4. **截取与淡出** — 保留 0.5 s 稳态，3 ms 淡入淡出，保存为 16-bit 44.1 kHz 单声道 WAV
5. **去重** — 每音保留信噪比最高的 2 个样本 — 从 ~340 候选段中得到 43 个

---

## License

MIT

---

*Built with Swift 6, SwiftUI, and Accelerate framework.*
