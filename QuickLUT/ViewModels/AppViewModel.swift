import Foundation
import SwiftUI

/// 顶层 ViewModel，连接 UI、Engine 和 PresetStore
@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published 状态

    @Published var params = ProcessingParams()
    @Published var selectedFileURL: URL?
    @Published var outputURL: URL?
    @Published var job = ProcessingJob()
    @Published var previewImageURL: URL?
    @Published var isGeneratingPreview = false

    // MARK: - 子组件

    let videoProcessor = VideoProcessor()
    let presetStore = PresetStore()

    private var previewDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("QuickLUT/previews", isDirectory: true)
    }

    // MARK: - 文件操作

    /// 用户选择视频文件后调用（拖放或文件选择器）
    func selectFile(_ url: URL) {
        guard VideoProcessor.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return
        }
        selectedFileURL = url
        previewImageURL = nil
        computeOutputPath(for: url)
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

    func generatePreview() {
        guard let input = selectedFileURL, !isGeneratingPreview else { return }
        guard let lutFileURL = VideoProcessor.resolveLUTFile(named: params.lutFileName) else {
            previewImageURL = nil
            return
        }

        isGeneratingPreview = true
        previewImageURL = nil

        Task {
            let result = await videoProcessor.generatePreview(
                inputURL: input,
                params: params,
                lutFileURL: lutFileURL,
                outputDir: previewDir
            )
            await MainActor.run {
                self.previewImageURL = result
                self.isGeneratingPreview = false
            }
        }
    }

    // MARK: - 编码

    func startEncoding() {
        guard let input = selectedFileURL, let output = outputURL,
              !job.status.isActive else { return }

        guard let lutFileURL = VideoProcessor.resolveLUTFile(named: params.lutFileName) else {
            job.status = .failed(error: "找不到 LUT 文件：\(params.lutFileName)")
            return
        }

        Task {
            await videoProcessor.process(inputURL: input, outputURL: output, params: params, lutFileURL: lutFileURL)
            self.job = videoProcessor.job
        }
    }

    func cancelEncoding() {
        videoProcessor.cancel()
        job = videoProcessor.job
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
}
