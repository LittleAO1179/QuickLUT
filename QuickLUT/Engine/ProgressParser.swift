import Foundation

/// 解析 ffmpeg -progress pipe:1 输出，提取编码进度
enum ProgressParser {

    /// 从一行 ffmpeg progress 输出中提取进度信息
    /// - Parameters:
    ///   - line: ffmpeg 输出的一行
    ///   - durationMs: 视频总时长（毫秒）
    /// - Returns: (progress 0.0...1.0, speed 倍率) 或 nil
    static func parse(line: String, durationMs: Int64) -> (progress: Double, speed: Double?)? {
        guard durationMs > 0 else { return nil }

        if line.hasPrefix("out_time_ms=") {
            let msStr = String(line.dropFirst("out_time_ms=".count))
            if let ms = Int64(msStr) {
                let progress = min(1.0, max(0.0, Double(ms) / Double(durationMs)))
                return (progress, nil)
            }
        }

        if line.hasPrefix("speed="), let speedStr = line.components(separatedBy: "=").last {
            let cleaned = speedStr.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "x", with: "")
            if let speed = Double(cleaned) {
                return (0, speed)
            }
        }

        return nil
    }

    /// 获取视频时长（毫秒）— 通过 ffprobe
    static func getVideoDuration(inputURL: URL, ffprobeURL: URL) throws -> Int64 {
        let process = Process()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "quiet", "-print_format", "json",
            "-show_format", inputURL.path
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let format = json["format"] as? [String: Any],
              let durationStr = format["duration"] as? String,
              let duration = Double(durationStr) else {
            throw NSError(domain: "QuickLUT", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法获取视频时长"])
        }

        return Int64(duration * 1_000_000)
    }
}
