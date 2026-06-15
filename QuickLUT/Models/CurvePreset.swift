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

    /// 切换曲线时推荐的配套参数。nil 表示不覆盖用户当前值。
    struct RecommendedParams {
        var saturation: Double?
        var contrast: Double?
        var brightness: Double?
        var gamma: Double?
    }

    var recommendedParams: RecommendedParams {
        switch self {
        case .none:
            return RecommendedParams()
        case .light:
            return RecommendedParams(saturation: 1.0, contrast: 1.02, brightness: 0.0, gamma: 1.0)
        case .moderate:
            return RecommendedParams(saturation: 1.0, contrast: 1.04, brightness: 0.0, gamma: 1.01)
        case .strong:
            return RecommendedParams(saturation: 0.95, contrast: 1.08, brightness: 0.0, gamma: 1.02)
        case .filmLight:
            return RecommendedParams(saturation: 0.90, contrast: 1.06, brightness: -0.02, gamma: 1.02)
        case .filmMedium:
            return RecommendedParams(saturation: 0.85, contrast: 1.10, brightness: -0.03, gamma: 1.04)
        case .filmStrong:
            return RecommendedParams(saturation: 0.78, contrast: 1.15, brightness: -0.05, gamma: 1.06)
        }
    }
}
