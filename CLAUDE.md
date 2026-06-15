# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

QuickLUT 是一个 macOS 菜单栏应用（LSUIElement = YES，无 Dock 图标），通过状态栏弹出 popover，让用户拖放视频文件、选择 LUT（.cube 格式）并进行调色参数调整，最后用 ffmpeg 导出调色后的 HEVC 视频。

## 构建与开发

- **项目生成**：`python3 gen_project.py` — 扫描 `QuickLUT/` 源码目录，重新生成 `.xcodeproj/project.pbxproj`（UUID 基于 MD5 确定性生成）
- **构建**：用 Xcode 打开 `QuickLUT.xcodeproj`，`xcodebuild -project QuickLUT.xcodeproj -scheme QuickLUT build`，或直接用 Xcode GUI
- **运行**：Xcode 中 ⌘R，target 为 macOS 14.0+
- **无测试**：项目目前没有测试 target
- **无外部依赖**：零 Swift Package 依赖，唯一外部工具是系统上需安装 `ffmpeg`（含 `ffprobe`）
- **Swift 5.0**，部署目标 macOS 14.0

## 架构

**MVVM** 架构，入口文件仅 ~1700 行 Swift：

```
QuickLUTApp.swift          → @main，仅 Settings scene（空）
AppDelegate.swift          → 根控制器：NSStatusItem + NSPopover + 事件监听
  ├── ViewModels/
  │     AppViewModel.swift  → @MainActor ObservableObject，连接 UI 与 Engine
  │     PresetStore.swift   → 预设持久化（内置 + 用户预设，JSON 文件存储）
  ├── Views/               → SwiftUI 视图，通过 @EnvironmentObject 获取 AppViewModel
  ├── Models/              → 纯数据类型（ProcessingParams, ProcessingJob, Preset, CurvePreset）
  └── Engine/              → 无状态工具 + VideoProcessor（ffmpeg 交互层）
        FilterChainBuilder  → 构建 ffmpeg -filter_complex 字符串（移植自 Python color_ai.py）
        ColorBalanceBuilder → 色温→colorbalance 滤镜参数映射
        ProgressParser      → 解析 ffmpeg -progress pipe:1 输出
        FFmpegLocator       → 查找系统上的 ffmpeg/ffprobe
        VideoProcessor      → 后台线程执行 ffmpeg 编码 + 预览帧提取
```

**数据流**：用户在 SwiftUI View 中调节参数 → `AppViewModel.params` 被修改 → 调用 `generatePreview()` 或 `startEncoding()` → `VideoProcessor` 在 `Task.detached` 中异步执行 ffmpeg → 通过 Combine `$job` 发布者同步进度到 UI

**ffmpeg 编码参数**（VideoProcessor.swift:83-96）：
- 视频：`hevc_videotoolbox` 硬编码，20Mbps，10-bit 4:2:0，Rec.709 色彩元数据，`+faststart`
- 滤镜链：curves → lut3d（可选 blend 混合）→ colorbalance → eq → [out]
- 预览：用 `-ss` 定位到视频中点，提取单帧 JPEG（缩放至 640:-1）
- 进度：从 ffmpeg stdout 逐行解析 `out_time_ms`，结合 ffprobe 获取的总时长计算百分比

## 注意事项

- **gen_project.py 已在 .gitignore 中**：该脚本本身不提交，只提交它生成的 pbxproj
- **LUT 文件查找有三层回退**：Bundle 内 LUTs/ → 源码目录 QuickLUT/LUTs/ → 硬编码的 `~/Desktop/File/Projects/LutAutoProcess/luts/` 路径
- **预览与编码在不同目录**：预览图在临时目录 `QuickLUT/previews/`，编码输出在输入视频同目录
- **Popover 行为**：`.applicationDefined` 模式，手动管理关闭（点击外部/Esc/再次点击图标）
- **分支命名**：特性分支用 `feature/` 前缀，主分支 `main`，开发分支 `develop`
