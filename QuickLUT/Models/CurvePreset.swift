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

    /// 切换曲线时的完整配套参数（白平衡/分色 + 基础调整，不含 LUT）。
    struct RecommendedParams {
        var temperature: Double
        var tint: Double
        var shadowTemperature: Double
        var highlightTemperature: Double
        var saturation: Double
        var contrast: Double
        var brightness: Double
        var gamma: Double

        func apply(to params: ProcessingParams, preCurve: CurvePreset) -> ProcessingParams {
            var p = params
            p.preCurve = preCurve
            p.temperature = temperature
            p.tint = tint
            p.shadowTemperature = shadowTemperature
            p.highlightTemperature = highlightTemperature
            p.saturation = saturation
            p.contrast = contrast
            p.brightness = brightness
            p.gamma = gamma
            return p
        }
    }

    var recommendedParams: RecommendedParams {
        switch self {
        case .none:
            return RecommendedParams(
                temperature: 0, tint: 0, shadowTemperature: 0, highlightTemperature: 0,
                saturation: 1.0, contrast: 1.0, brightness: 0.0, gamma: 1.0
            )
        case .light:
            return RecommendedParams(
                temperature: 0.05, tint: 0.05,
                shadowTemperature: -0.10, highlightTemperature: 0.10,
                saturation: 1.0, contrast: 1.02, brightness: 0.0, gamma: 1.0
            )
        case .moderate:
            return RecommendedParams(
                temperature: 0.04, tint: 0.08,
                shadowTemperature: -0.20, highlightTemperature: 0.25,
                saturation: 1.0, contrast: 1.04, brightness: 0.0, gamma: 1.01
            )
        case .strong:
            return RecommendedParams(
                temperature: 0.04, tint: 0.08,
                shadowTemperature: -0.25, highlightTemperature: 0.30,
                saturation: 0.95, contrast: 1.08, brightness: 0.0, gamma: 1.02
            )
        case .filmLight:
            return RecommendedParams(
                temperature: 0.03, tint: 0.08,
                shadowTemperature: -0.30, highlightTemperature: 0.30,
                saturation: 0.90, contrast: 1.06, brightness: -0.02, gamma: 1.02
            )
        case .filmMedium:
            return RecommendedParams(
                temperature: 0.04, tint: 0.10,
                shadowTemperature: -0.40, highlightTemperature: 0.40,
                saturation: 0.85, contrast: 1.10, brightness: -0.03, gamma: 1.04
            )
        case .filmStrong:
            return RecommendedParams(
                temperature: 0.03, tint: 0.10,
                shadowTemperature: -0.35, highlightTemperature: 0.35,
                saturation: 0.78, contrast: 1.15, brightness: -0.05, gamma: 1.06
            )
        }
    }
}
