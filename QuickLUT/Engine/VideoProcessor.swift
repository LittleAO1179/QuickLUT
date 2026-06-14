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

    // MARK: - LUT 文件查找

    /// 查找 LUT 文件，先查 bundle，再查当前工作目录
    static func resolveLUTFile(named lutFileName: String) -> URL? {
        // 1. 先查 bundle Resources/LUTs/
        if let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("LUTs") {
            let url = bundleDir.appendingPathComponent(lutFileName)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // 2. 回退：项目源码目录（Xcode 开发时）
        let sourcePaths = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("QuickLUT/LUTs/\(lutFileName)"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("LUTs/\(lutFileName)"),
        ]
        for url in sourcePaths {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // 3. LutAutoProcess 项目路径
        let altPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/File/Projects/LutAutoProcess/luts/\(lutFileName)")
        if FileManager.default.fileExists(atPath: altPath.path) {
            return altPath
        }

        return nil
    }

    // MARK: - 执行 ffmpeg 命令（复用逻辑）

    private func runFFmpeg(arguments: [String]) async -> (exitCode: Int32, stderr: String) {
        guard let ffmpegURL = FFmpegLocator.locate() else {
            return (-1, "未找到 ffmpeg")
        }

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

            return (process.terminationStatus, stderrStr)
        } catch {
            return (-1, "启动 ffmpeg 失败: \(error.localizedDescription)")
        }
    }

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

        guard FFmpegLocator.isAvailable() else {
            job.status = .failed(error: "未找到 ffmpeg。请使用 Homebrew 安装：brew install ffmpeg")
            isProcessing = false
            return
        }

        guard let ffprobeURL = FFmpegLocator.locateFFprobe() else {
            job.status = .failed(error: "未找到 ffprobe。请确保 ffmpeg 安装完整")
            isProcessing = false
            return
        }

        guard FileManager.default.fileExists(atPath: lutFileURL.path) else {
            job.status = .failed(error: "LUT 文件不存在：\(lutFileURL.path)")
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

        let arguments = [
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

        job.status = .encoding(progress: 0)
        currentProcess = Process()
        currentProcess?.executableURL = FFmpegLocator.locate()
        currentProcess?.arguments = arguments
        let stderrPipe = Pipe()
        currentProcess?.standardOutput = Pipe()
        currentProcess?.standardError = stderrPipe
        currentProcess?.standardInput = FileHandle.nullDevice

        do {
            try currentProcess?.run()
            currentProcess?.waitUntilExit()

            let exitCode = currentProcess?.terminationStatus ?? -1
            if exitCode != 0 {
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
                // 提取 stderr 最后几行（含关键错误信息）
                let lines = stderrStr.components(separatedBy: "\n").filter { !$0.isEmpty }
                let lastLines = lines.suffix(5).joined(separator: "\n")
                job.status = .failed(error: "ffmpeg 编码失败 (exit \(exitCode)):\n\(lastLines)")
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
        guard FFmpegLocator.isAvailable(),
              FFmpegLocator.locateFFprobe() != nil else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: lutFileURL.path) else {
            print("[QuickLUT] LUT file not found: \(lutFileURL.path)")
            return nil
        }

        let durationMs: Int64
        do {
            durationMs = try ProgressParser.getVideoDuration(
                inputURL: inputURL,
                ffprobeURL: FFmpegLocator.locateFFprobe()!
            )
        } catch {
            print("[QuickLUT] getVideoDuration failed: \(error)")
            return nil
        }

        let midSeconds = Double(durationMs) / 2_000_000.0
        let filterComplex = FilterChainBuilder.build(
            params: params,
            lutFilePath: lutFileURL.path,
            scale: "640:-1"
        )
        let previewURL = outputDir.appendingPathComponent("preview.jpg")

        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let result = await runFFmpeg(arguments: [
            "-y",
            "-ss", String(format: "%.2f", midSeconds),
            "-i", inputURL.path,
            "-filter_complex", filterComplex,
            "-map", "[out]",
            "-frames:v", "1",
            "-q:v", "3",
            previewURL.path
        ])

        if result.exitCode != 0 {
            print("[QuickLUT] Preview ffmpeg failed: \(result.stderr)")
            return nil
        }

        return FileManager.default.fileExists(atPath: previewURL.path) ? previewURL : nil
    }
}
