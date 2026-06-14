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

    // MARK: - 子组件

    let videoProcessor = VideoProcessor()
    let presetStore = PresetStore()

    // MARK: - 文件操作

    /// 用户选择视频文件后调用
    func selectFile(_ url: URL) {
        guard VideoProcessor.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return
        }
        selectedFileURL = url
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

    // MARK: - 编码

    func startEncoding() {
        guard let input = selectedFileURL, let output = outputURL,
              !job.status.isActive else { return }

        guard let lutDir = Bundle.main.resourceURL?.appendingPathComponent("LUTs") else {
            job.status = .failed(error: "找不到 LUT 资源目录")
            return
        }
        let lutFileURL = lutDir.appendingPathComponent(params.lutFileName)

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
