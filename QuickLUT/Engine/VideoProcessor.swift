import Foundation
import AppKit
import CoreImage

/// 管理视频处理（UI 状态在主线程，解码/编码走原生 AVFoundation + Core Image）
@MainActor
final class VideoProcessor: ObservableObject {

    @Published var job = ProcessingJob()
    @Published var isProcessing = false

    /// 支持的视频文件扩展名
    static let supportedExtensions: Set<String> = [
        "mp4", "mov", "mxf", "avi", "mkv", "webm", "m4v"
    ]

    private var encodeProcessor: AVColorProcessor?
    private let previewProcessor = AVColorProcessor()

    // MARK: - LUT 文件查找

    static func resolveLUTFile(named lutFileName: String) -> URL? {
        if let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("LUTs") {
            let url = bundleDir.appendingPathComponent(lutFileName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let sourcePaths = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("QuickLUT/LUTs/\(lutFileName)"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("LUTs/\(lutFileName)"),
        ]
        for url in sourcePaths {
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let altPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/File/Projects/LutAutoProcess/luts/\(lutFileName)")
        if FileManager.default.fileExists(atPath: altPath.path) { return altPath }
        return nil
    }

    // MARK: - 编码

    func startEncoding(inputURL: URL, outputURL: URL, params: ProcessingParams, lutFileURL: URL) {
        guard !isProcessing else { return }
        isProcessing = true
        job = ProcessingJob(url: inputURL)
        job.outputURL = outputURL
        job.status = .preparing

        let processor = AVColorProcessor()
        encodeProcessor = processor

        Task {
            // 解析 LUT + 烘焙合并立方体（后台线程，避免阻塞 UI）
            let cubeData = await Self.bakeCube(params: params, lutFileURL: lutFileURL)
            guard let cubeData,
                  let filter = Self.makeFilter(cubeData: cubeData) else {
                self.fail("LUT 解析失败：\(lutFileURL.lastPathComponent)")
                return
            }

            self.job.status = .encoding(progress: 0)
            do {
                try await processor.export(inputURL: inputURL, outputURL: outputURL, filter: filter) { [weak self] p in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if case .encoding = self.job.status {
                            self.job.status = .encoding(progress: p)
                        }
                    }
                }
                self.job.status = .completed(outputPath: outputURL.path)
                self.isProcessing = false
            } catch AVColorProcessor.ProcessError.cancelled {
                self.job.status = .cancelled
                self.isProcessing = false
            } catch {
                self.fail(error.localizedDescription)
            }
        }
    }

    func cancel() {
        encodeProcessor?.cancel()
        isProcessing = false
        job.status = .cancelled
    }

    private func fail(_ msg: String) {
        job.status = .failed(error: msg)
        isProcessing = false
    }

    // MARK: - 预览（单帧，Core Image）

    func generatePreview(inputURL: URL, params: ProcessingParams, lutFileURL: URL) async -> NSImage? {
        guard let cubeData = await Self.bakeCube(params: params, lutFileURL: lutFileURL),
              let filter = Self.makeFilter(cubeData: cubeData) else {
            return nil
        }
        do {
            let cgImage = try await previewProcessor.renderPreviewFrame(inputURL: inputURL, filter: filter)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("[QuickLUT] 预览失败：\(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 合并 LUT 构建（后台烘焙数据 + 主线程建滤镜）

    nonisolated private static func bakeCube(params: ProcessingParams, lutFileURL: URL) async -> Data? {
        await Task.detached {
            guard let lut = try? CubeLUT(contentsOf: lutFileURL) else { return nil }
            return CombinedLUTBuilder.bakeCubeData(params: params, lut: lut, size: CombinedLUTBuilder.cubeSize)
        }.value
    }

    nonisolated private static func makeFilter(cubeData: Data) -> CIFilter? {
        CIFilter(name: "CIColorCube", parameters: [
            "inputCubeDimension": CombinedLUTBuilder.cubeSize,
            "inputCubeData": cubeData
        ])
    }
}
