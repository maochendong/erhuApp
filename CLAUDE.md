# 二胡识谱 - Erhu Score Trainer

## 项目概述

二胡识谱是一款 iOS 二胡教学应用，帮助学习者练习识谱和音准。

## 技术栈

- Swift 6.0+
- SwiftUI (iOS 18+)
- AVFoundation / Accelerate (音频处理)
- Swift Package Manager

## 项目结构

```
Sources/ErhuApp/
├── ErhuApp.swift          # App 入口
├── Info.plist             # 应用配置
├── Models/
│   ├── Note.swift         # 音符模型
│   ├── Score.swift        # 乐谱模型
│   └── Lesson.swift       # 课程模型
├── Views/
│   ├── ContentView.swift  # 主视图 / Tab 导航
│   ├── PracticeView.swift # 练习页面
│   ├── ScoreView.swift    # 乐谱显示组件
│   ├── ScoreLibraryView.swift # 曲库页面
│   └── SettingsView.swift # 设置页面
├── Audio/
│   └── AudioEngine.swift  # 音频引擎 (麦克风 + 音高检测)
└── Services/
    ├── ScoreService.swift  # 曲库管理
    └── PitchJudger.swift   # 音准判断
```

## 开发

1. 用 Xcode 打开 `Package.swift`
2. 选择 iOS Simulator 或真机运行
3. 首次使用需授权麦克风权限

## 架构

- **AudioEngine**: 基于 AVAudioEngine 的实时音频处理，使用自相关算法进行音高检测
- **PitchJudger**: 对比演奏频率与目标频率，计算音分偏差
- **ScoreService**: 内置简谱曲库管理

## 内置曲目

- 小星星, 两只老虎, 茉莉花, 摇篮曲, 赛马
