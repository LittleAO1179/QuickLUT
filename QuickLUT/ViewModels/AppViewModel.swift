import Foundation
import SwiftUI
import Combine

/// 顶层 ViewModel，连接 UI、Engine 和 PresetStore
@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published 状态

    @Published var params = ProcessingParams()
    @Published var selectedFileURL: URL?
    @Published var outputURL: URL?
    @Published var job = ProcessingJob()
    @Published var previewImage: NSImage?
    @Published var isGeneratingPreview = false

    // MARK: - 子组件

    let videoProcessor = VideoProcessor()
    let presetStore = PresetStore()
    private var cancellables = Set<AnyCancellable>()
    private var previewSeq = 0
    @Published private(set) var previewToken = UUID()

    init() {
        videoProcessor.$job
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newJob in
                self?.job = newJob
            }
            .store(in: &cancellables)

        $params
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.requestPreview()
            }
            .store(in: &cancellables)

        // 启动时与预设选择器同步（PresetStore 已默认选中第一个）
        if let id = presetStore.selectedPresetID,
           let preset = presetStore.presets.first(where: { $0.id == id }) {
            params = preset.params
        }
    }

    // MARK: - 文件操作

    /// 用户选择视频文件后调用（拖放或文件选择器）
    func selectFile(_ url: URL) {
        guard VideoProcessor.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return
        }
        selectedFileURL = url
        previewImage = nil
        computeOutputPath(for: url)
        requestPreview()
    }

    /// 更新单个参数字段（整体赋值，触发 @Published）。
    func setParam<T>(_ keyPath: WritableKeyPath<ProcessingParams, T>, _ value: T) {
        var copy = params
        copy[keyPath: keyPath] = value
        params = copy
    }

    /// Picker 等控件用 Binding。
    func binding<T>(_ keyPath: WritableKeyPath<ProcessingParams, T>) -> Binding<T> {
        Binding(
            get: { self.params[keyPath: keyPath] },
            set: { self.setParam(keyPath, $0) }
        )
    }

    /// 更新输出路径
    private func computeOutputPath(for inputURL: URL) {
        let dir = inputURL.deletingLastPathComponent()
        let stem = inputURL.deletingPathExtension().lastPathComponent

        var candidate = dir.appendingPathComponent("\(stem)_graded.mp4")
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(stem)_graded_\(counter).mp4")
            counter += 1
        }
        outputURL = candidate
    }

    // MARK: - 预览

    func requestPreview() {
        guard let input = selectedFileURL else { return }
        guard let lutFileURL = VideoProcessor.resolveLUTFile(named: params.lutFileName) else {
            previewImage = nil
            return
        }

        previewSeq += 1
        let seq = previewSeq
        let snapshot = params
        isGeneratingPreview = true

        Task {
            let result = await videoProcessor.generatePreview(
                inputURL: input,
                params: snapshot,
                lutFileURL: lutFileURL
            )
            guard seq == self.previewSeq else { return }
            self.previewImage = result
            self.previewToken = UUID()
            self.isGeneratingPreview = false
        }
    }

    /// 手动触发预览（供按钮调用，与 requestPreview 相同逻辑）。
    func generatePreview() {
        requestPreview()
    }

    // MARK: - 编码

    func startEncoding() {
        guard let input = selectedFileURL, let output = outputURL,
              !job.status.isActive else { return }

        guard let lutFileURL = VideoProcessor.resolveLUTFile(named: params.lutFileName) else {
            job.status = .failed(error: "找不到 LUT 文件：\(params.lutFileName)")
            return
        }

        videoProcessor.startEncoding(
            inputURL: input,
            outputURL: output,
            params: params,
            lutFileURL: lutFileURL
        )
    }

    func cancelEncoding() {
        videoProcessor.cancel()
    }

    // MARK: - 预设

    func applyPreset(_ preset: Preset) {
        params = preset.params
        presetStore.selectedPresetID = preset.id
    }

    func saveCurrentPreset(name: String) {
        presetStore.saveCurrent(as: name, params: params)
    }

    func deletePreset(_ preset: Preset) {
        presetStore.delete(preset)
    }

    /// 切换曲线：曲线 + 白平衡/分色 + 基础调整，一次写回整套配套参数。
    func applyCurve(_ curve: CurvePreset) {
        guard curve != params.preCurve else { return }
        params = curve.recommendedParams.apply(to: params, preCurve: curve)
    }
}
