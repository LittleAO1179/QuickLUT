import Foundation

/// 管理 ffmpeg 视频处理（UI 状态在主线程，ffmpeg 执行在后台）
@MainActor
final class VideoProcessor: ObservableObject {

    @Published var job = ProcessingJob()
    @Published var isProcessing = false

    /// 支持的视频文件扩展名
    static let supportedExtensions: Set<String> = [
        "mp4", "mov", "mxf", "avi", "mkv", "webm", "m4v"
    ]

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

    // MARK: - 后台执行 ffmpeg（非主线程）

    /// 在后台线程执行 ffmpeg，通过回调报告进度和结果
    func startEncoding(
        inputURL: URL,
        outputURL: URL,
        filterComplex: String
    ) {
        guard !isProcessing else { return }
        isProcessing = true
        job = ProcessingJob(url: inputURL)
        job.outputURL = outputURL
        job.status = .preparing

        // 确保输出目录存在
        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // 在后台线程执行所有阻塞操作
        Task.detached { [weak self] in
            guard let self = self else { return }

            // 获取 ffmpeg 路径（在后台查，避免主线程 I/O）
            guard let ffmpegURL = FFmpegLocator.locate(),
                  let ffprobeURL = FFmpegLocator.locateFFprobe() else {
                await self.fail("未找到 ffmpeg")
                return
            }

            // 获取视频时长（后台 I/O）
            let durationMs: Int64
            do {
                durationMs = try ProgressParser.getVideoDuration(inputURL: inputURL, ffprobeURL: ffprobeURL)
            } catch {
                await self.fail("无法读取视频文件：\(error.localizedDescription)")
                return
            }

            // 更新状态：开始编码
            await MainActor.run { self.job.status = .encoding(progress: 0) }

            // 启动 ffmpeg
            let process = Process()
            process.executableURL = ffmpegURL
            process.arguments = [
                "-i", inputURL.path,
                "-filter_complex", filterComplex,
                "-map", "[out]",
                "-map", "0:a?",
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
            process.standardInput = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                await self.fail("启动 ffmpeg 失败：\(error.localizedDescription)")
                return
            }

            // 后台读取进度（不阻塞，异步读取 stdout）
            let progressTask = Task.detached {
                for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
                    if Task.isCancelled { break }
                    if let result = ProgressParser.parse(line: line, durationMs: durationMs),
                       result.progress > 0 {
                        await MainActor.run {
                            if case .encoding = self.job.status {
                                self.job.status = .encoding(progress: result.progress)
                            }
                        }
                    }
                }
            }

            // 阻塞等待完成（在后台线程，不阻塞 UI）
            process.waitUntilExit()
            progressTask.cancel()

            let exitCode = process.terminationStatus
            if exitCode != 0 {
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
                let lines = stderrStr.components(separatedBy: "\n").filter { !$0.isEmpty }
                let lastLines = lines.suffix(5).joined(separator: "\n")
                await self.fail("ffmpeg 编码失败 (exit \(exitCode)):\n\(lastLines)")
            } else {
                await MainActor.run {
                    self.job.status = .completed(outputPath: outputURL.path)
                    self.isProcessing = false
                }
            }
        }
    }

    /// 取消当前处理
    func cancel() {
        isProcessing = false
        job.status = .cancelled
    }

    @MainActor
    private func fail(_ msg: String) {
        job.status = .failed(error: msg)
        isProcessing = false
    }

    // MARK: - 预览（同样后台执行）

    func generatePreview(
        inputURL: URL,
        params: ProcessingParams,
        lutFileURL: URL,
        outputDir: URL
    ) async -> URL? {
        guard FFmpegLocator.isAvailable(),
              let ffprobeURL = FFmpegLocator.locateFFprobe() else { return nil }
        guard FileManager.default.fileExists(atPath: lutFileURL.path) else {
            print("[QuickLUT] LUT file not found: \(lutFileURL.path)")
            return nil
        }

        // 在后台线程执行 I/O
        return await Task.detached {
            let durationMs: Int64
            do {
                durationMs = try ProgressParser.getVideoDuration(inputURL: inputURL, ffprobeURL: ffprobeURL)
            } catch {
                print("[QuickLUT] getVideoDuration failed: \(error)")
                return nil as URL?
            }

            let midSeconds = Double(durationMs) / 2_000_000.0
            let filterComplex = FilterChainBuilder.build(
                params: params,
                lutFilePath: lutFileURL.path,
                scale: "640:-1"
            )
            let previewURL = outputDir.appendingPathComponent("preview.jpg")
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            guard let ffmpegURL = FFmpegLocator.locate() else { return nil as URL? }

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
            process.standardOutput = Pipe()
            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardInput = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil as URL?
            }

            if process.terminationStatus != 0 {
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
                print("[QuickLUT] Preview ffmpeg failed: \(stderrStr)")
                return nil as URL?
            }

            return FileManager.default.fileExists(atPath: previewURL.path) ? previewURL : nil
        }.value
    }
}
