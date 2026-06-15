import Foundation
import AVFoundation
import CoreImage
import VideoToolbox

/// 原生 AVFoundation + Core Image 调色导出管线。
/// 硬件解码 → GPU 应用合并 LUT → VideoToolbox HEVC 10-bit 硬件编码，音频直通。
final class AVColorProcessor {

    enum ProcessError: LocalizedError {
        case noVideoTrack
        case cannotCreateReaderWriter
        case readerFailed(String)
        case writerFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "视频文件中没有视频轨道"
            case .cannotCreateReaderWriter: return "无法创建读写器"
            case .readerFailed(let s): return "解码失败：\(s)"
            case .writerFailed(let s): return "编码失败：\(s)"
            case .cancelled: return "已取消"
            }
        }
    }

    private let ciContext: CIContext
    private var isCancelled = false

    init() {
        // 关闭色彩管理：CI 不做 gamma 线性化，LUT 直接作用在原始编码值上（与 ffmpeg 一致）
        let options: [CIContextOption: Any] = [
            .workingColorSpace: NSNull(),
            .cacheIntermediates: false
        ]
        if let device = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: device, options: options)
        } else {
            ciContext = CIContext(options: options)
        }
    }

    func cancel() { isCancelled = true }

    /// 导出。`progress` 在任意线程回调（0...1）。
    func export(
        inputURL: URL,
        outputURL: URL,
        filter: CIFilter,
        bitRate: Int = 20_000_000,
        progress: @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: inputURL)
        let durationSeconds = try await asset.load(.duration).seconds

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ProcessError.noVideoTrack
        }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first

        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let frameRate = (try? await videoTrack.load(.nominalFrameRate)) ?? 30

        // ---- Reader ----
        guard let reader = try? AVAssetReader(asset: asset) else { throw ProcessError.cannotCreateReaderWriter }
        let videoReaderOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange]
        )
        videoReaderOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoReaderOutput) else { throw ProcessError.cannotCreateReaderWriter }
        reader.add(videoReaderOutput)

        var audioReaderOutput: AVAssetReaderTrackOutput?
        if let audioTrack = audioTrack {
            let out = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil) // 直通（不解码）
            if reader.canAdd(out) { reader.add(out); audioReaderOutput = out }
        }

        // ---- Writer ----
        try? FileManager.default.removeItem(at: outputURL)
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw ProcessError.cannotCreateReaderWriter
        }
        writer.shouldOptimizeForNetworkUse = true // 等价 +faststart

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(abs(naturalSize.width)),
            AVVideoHeightKey: Int(abs(naturalSize.height)),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoMaxKeyFrameIntervalDurationKey: 2,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String,
                AVVideoExpectedSourceFrameRateKey: Int(frameRate.rounded())
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = transform
        guard writer.canAdd(videoInput) else { throw ProcessError.cannotCreateReaderWriter }
        writer.add(videoInput)

        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                kCVPixelBufferWidthKey as String: Int(abs(naturalSize.width)),
                kCVPixelBufferHeightKey as String: Int(abs(naturalSize.height)),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )

        var audioInput: AVAssetWriterInput?
        if audioReaderOutput != nil, let audioTrack = audioTrack {
            let formats = try? await audioTrack.load(.formatDescriptions)
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: formats?.first)
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) { writer.add(input); audioInput = input }
        }

        // ---- Start ----
        guard reader.startReading() else {
            throw ProcessError.readerFailed(reader.error?.localizedDescription ?? "startReading 失败")
        }
        guard writer.startWriting() else {
            throw ProcessError.writerFailed(writer.error?.localizedDescription ?? "startWriting 失败")
        }
        writer.startSession(atSourceTime: .zero)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let group = DispatchGroup()

                // 视频处理
                group.enter()
                let videoQueue = DispatchQueue(label: "quicklut.video")
                videoInput.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
                    guard let self = self else { return }
                    while videoInput.isReadyForMoreMediaData {
                        if self.isCancelled { reader.cancelReading(); videoInput.markAsFinished(); group.leave(); return }
                        guard let sample = videoReaderOutput.copyNextSampleBuffer(),
                              let srcBuffer = CMSampleBufferGetImageBuffer(sample) else {
                            videoInput.markAsFinished(); group.leave(); return
                        }
                        let pts = CMSampleBufferGetPresentationTimeStamp(sample)
                        autoreleasepool {
                            let input = CIImage(cvPixelBuffer: srcBuffer)
                            filter.setValue(input, forKey: kCIInputImageKey)
                            guard let output = filter.outputImage,
                                  let pool = pixelAdaptor.pixelBufferPool else { return }
                            var pb: CVPixelBuffer?
                            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
                            if let pb = pb {
                                self.ciContext.render(output, to: pb, bounds: input.extent, colorSpace: nil)
                                pixelAdaptor.append(pb, withPresentationTime: pts)
                            }
                        }
                        if durationSeconds > 0 { progress(min(pts.seconds / durationSeconds, 1)) }
                    }
                }

                // 音频直通
                if let audioInput = audioInput, let audioReaderOutput = audioReaderOutput {
                    group.enter()
                    let audioQueue = DispatchQueue(label: "quicklut.audio")
                    audioInput.requestMediaDataWhenReady(on: audioQueue) {
                        while audioInput.isReadyForMoreMediaData {
                            if self.isCancelled { audioInput.markAsFinished(); group.leave(); return }
                            guard let sample = audioReaderOutput.copyNextSampleBuffer() else {
                                audioInput.markAsFinished(); group.leave(); return
                            }
                            audioInput.append(sample)
                        }
                    }
                }

                group.notify(queue: .global()) {
                    if self.isCancelled {
                        writer.cancelWriting()
                        cont.resume(throwing: ProcessError.cancelled)
                        return
                    }
                    if reader.status == .failed {
                        writer.cancelWriting()
                        cont.resume(throwing: ProcessError.readerFailed(reader.error?.localizedDescription ?? ""))
                        return
                    }
                    writer.finishWriting {
                        if writer.status == .completed {
                            cont.resume()
                        } else {
                            cont.resume(throwing: ProcessError.writerFailed(writer.error?.localizedDescription ?? "未知错误"))
                        }
                    }
                }
            }
        } onCancel: {
            self.cancel()
        }
    }

    // MARK: - 单帧预览

    /// 渲染中点单帧并应用 filter，返回 NSImage 可用的 CGImage。
    /// 与导出相同：10-bit YUV 解码 + 不做色彩管理，保证预览与成片一致。
    func renderPreviewFrame(inputURL: URL, filter: CIFilter, maxWidth: CGFloat = 640) async throws -> CGImage {
        let asset = AVURLAsset(url: inputURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ProcessError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let midTime = CMTime(seconds: duration.seconds / 2, preferredTimescale: 600)
        let transform = try await videoTrack.load(.preferredTransform)

        guard let reader = try? AVAssetReader(asset: asset) else { throw ProcessError.cannotCreateReaderWriter }
        let readerOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange]
        )
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else { throw ProcessError.cannotCreateReaderWriter }
        reader.add(readerOutput)
        reader.timeRange = CMTimeRange(start: midTime, duration: CMTime(value: 1, timescale: 600))

        guard reader.startReading() else {
            throw ProcessError.readerFailed(reader.error?.localizedDescription ?? "startReading 失败")
        }
        defer { reader.cancelReading() }

        guard let sample = readerOutput.copyNextSampleBuffer(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
            throw ProcessError.readerFailed("无法读取预览帧")
        }

        var input = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: transform)

        if input.extent.width > maxWidth {
            let scale = maxWidth / input.extent.width
            input = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage else { throw ProcessError.writerFailed("预览滤镜失败") }

        guard let result = ciContext.createCGImage(output, from: output.extent, format: .RGBA8, colorSpace: nil) else {
            throw ProcessError.writerFailed("预览渲染失败")
        }
        return result
    }
}
