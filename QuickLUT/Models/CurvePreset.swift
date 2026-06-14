import Foundation

/// 预定义曲线类型，对应 ffmpeg curves 滤镜的五点样条线
enum CurvePreset: String, CaseIterable, Codable {
    case none
    case light
    case moderate
    case strong
    case filmLight  = "film_light"
    case filmMedium = "film_medium"
    case filmStrong = "film_strong"

    var displayName: String {
        switch self {
        case .none:       return "无"
        case .light:      return "Light — 轻微保护"
        case .moderate:   return "Moderate — 通用调色"
        case .strong:     return "Strong — 强保护"
        case .filmLight:  return "Film Light — 柔和电影感"
        case .filmMedium: return "Film Medium — 标准电影感"
        case .filmStrong: return "Film Strong — 强烈电影感"
        }
    }

    /// ffmpeg curves 滤镜的曲线定义字符串，none 返回 nil
    var ffmpegCurveDefinition: String? {
        switch self {
        case .none:       return nil
        case .light:      return "0/0.01 0.2/0.22 0.5/0.5 0.8/0.79 1/0.98"
        case .moderate:   return "0/0.03 0.2/0.24 0.5/0.5 0.8/0.76 1/0.94"
        case .strong:     return "0/0.05 0.2/0.28 0.5/0.5 0.8/0.72 1/0.90"
        case .filmLight:  return "0/0.03 0.15/0.18 0.5/0.5 0.85/0.80 1/0.94"
        case .filmMedium: return "0/0.045 0.15/0.20 0.5/0.5 0.85/0.78 1/0.90"
        case .filmStrong: return "0/0.06 0.15/0.22 0.5/0.5 0.85/0.75 1/0.86"
        }
    }
}
