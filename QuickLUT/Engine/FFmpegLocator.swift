import Foundation

/// 定位系统上的 ffmpeg 可执行文件
enum FFmpegLocator {

    /// 已缓存的 ffmpeg 路径
    private static var cachedURL: URL?

    /// 查找 ffmpeg 路径
    static func locate() -> URL? {
        if let cached = cachedURL, FileManager.default.isExecutableFile(atPath: cached.path) {
            return cached
        }

        let searchPaths = [
            "/opt/homebrew/bin/ffmpeg",       // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",          // Intel Homebrew
            "/opt/local/bin/ffmpeg",          // MacPorts
        ]

        for path in searchPaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.isExecutableFile(atPath: path) {
                cachedURL = url
                return url
            }
        }

        // 通过 /usr/bin/env 查找
        let whichTask = Process()
        whichTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        whichTask.arguments = ["which", "ffmpeg"]
        let pipe = Pipe()
        whichTask.standardOutput = pipe
        whichTask.standardError = FileHandle.nullDevice

        do {
            try whichTask.run()
            whichTask.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               FileManager.default.isExecutableFile(atPath: path) {
                let url = URL(fileURLWithPath: path)
                cachedURL = url
                return url
            }
        } catch {
            // fall through
        }

        return nil
    }

    /// 从 ffmpeg 路径推导 ffprobe 路径
    static func locateFFprobe() -> URL? {
        guard let ffmpegURL = locate() else { return nil }
        let ffprobeURL = ffmpegURL
            .deletingLastPathComponent()
            .appendingPathComponent("ffprobe")
        if FileManager.default.isExecutableFile(atPath: ffprobeURL.path) {
            return ffprobeURL
        }
        return nil
    }

    /// 检查 ffmpeg 是否可用
    static func isAvailable() -> Bool {
        locate() != nil
    }
}
