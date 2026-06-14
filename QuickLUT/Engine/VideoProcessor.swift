import Foundation

/// 管理 ffmpeg 视频处理进程
@MainActor
final class VideoProcessor: ObservableObject {

    @Published var job = ProcessingJob()
    @Published var isProcessing = false

    private var currentProcess: Process?
    private var progressTask: Task<Void, Never>?

    /// 支持的视频文件扩展名
    static let supportedExtensions: Set<String> = [
        "mp4", "mov", "mxf", "avi", "mkv", "webm", "m4v"
    ]

    // MARK: - Public API

    /// 开始处理视频
    func process(
        inputURL: URL,
        outputURL: URL,
        params: ProcessingParams,
        lutFileURL: URL
    ) async {
        guard !isProcessing else { return }
        isProcessing = true
        job = ProcessingJob(url: inputURL)
        job.outputURL = outputURL

        guard let ffmpegURL = FFmpegLocator.locate() else {
            job.status = .failed(error: "未找到 ffmpeg。请使用 Homebrew 安装：brew install ffmpeg")
            isProcessing = false
            return
        }

        guard let ffprobeURL = FFmpegLocator.locateFFprobe() else {
            job.status = .failed(error: "未找到 ffprobe。请确保 ffmpeg 安装完整")
            isProcessing = false
            return
        }

        // 获取视频时长
        let durationMs: Int64
        do {
            job.status = .preparing
            durationMs = try ProgressParser.getVideoDuration(inputURL: inputURL, ffprobeURL: ffprobeURL)
        } catch {
            job.status = .failed(error: "无法读取视频文件：\(error.localizedDescription)")
            isProcessing = false
            return
        }

        // 构建 filter_complex
        let filterComplex = FilterChainBuilder.build(params: params, lutFilePath: lutFileURL.path)

        // 确保输出目录存在
        let outputDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // 构建 ffmpeg 命令
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-i", inputURL.path,
            "-filter_complex", filterComplex,
            "-map", "[out]",
            "-c:v", "hevc_videotoolbox",
            "-pix_fmt", "yuv420p10le",
            "-b:v", "20M", "-maxrate", "25M", "-bufsize", "25M",
            "-c:a", "copy",
            "-tag:v", "hvc1",
            "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
            "-movflags", "+faststart",
            "-progress", "pipe:1", "-nostats", "-y",
            outputURL.path
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        currentProcess = process
        job.status = .encoding(progress: 0)

        // 在后台读取进度
        progressTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
                    if Task.isCancelled { break }
                    if let result = ProgressParser.parse(line: line, durationMs: durationMs) {
                        if case .encoding = self.job.status, result.progress > 0 {
                            await MainActor.run {
                                self.job.status = .encoding(progress: result.progress)
                            }
                        }
                    }
                }
            } catch {
                // pipe closed or read error, ignore
            }
        }

        // 执行进程
        do {
            try process.run()
            process.waitUntilExit()
            progressTask?.cancel()

            if process.terminationReason == .uncaughtSignal || process.terminationStatus != 0 {
                let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "未知错误"
                job.status = .failed(error: "ffmpeg 编码失败 (exit \(process.terminationStatus)): \(String(errorMsg.prefix(200)))")
            } else {
                job.status = .completed(outputPath: outputURL.path)
            }
        } catch {
            job.status = .failed(error: "启动 ffmpeg 失败：\(error.localizedDescription)")
        }

        currentProcess = nil
        isProcessing = false
    }

    /// 取消当前处理
    func cancel() {
        currentProcess?.interrupt()
        currentProcess?.terminate()
        progressTask?.cancel()
        job.status = .cancelled
        isProcessing = false
    }

    // MARK: - 预览

    /// 生成视频中间帧的调色预览图
    @MainActor
    func generatePreview(
        inputURL: URL,
        params: ProcessingParams,
        lutFileURL: URL,
        outputDir: URL
    ) async -> URL? {
        guard let ffmpegURL = FFmpegLocator.locate(),
              let ffprobeURL = FFmpegLocator.locateFFprobe() else {
            return nil
        }

        let durationMs: Int64
        do {
            durationMs = try ProgressParser.getVideoDuration(inputURL: inputURL, ffprobeURL: ffprobeURL)
        } catch {
            return nil
        }

        let midSeconds = Double(durationMs) / 2_000_000.0  // 取视频中点
        let filterComplex = FilterChainBuilder.build(params: params, lutFilePath: lutFileURL.path, scale: "640:-1")
        let previewURL = outputDir.appendingPathComponent("preview.jpg")

        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-y",
            "-ss", String(format: "%.2f", midSeconds),
            "-i", inputURL.path,
            "-filter_complex", filterComplex,
            "-map", "[out]",
            "-frames:v", "1",
            "-q:v", "3",
            previewURL.path
        ]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0, FileManager.default.fileExists(atPath: previewURL.path) {
                return previewURL
            }
        } catch {}

        return nil
    }
}
