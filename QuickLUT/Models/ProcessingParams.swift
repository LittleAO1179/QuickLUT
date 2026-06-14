import Foundation

/// 调色参数集合，可直接 Codable 序列化为预设 JSON
struct ProcessingParams: Codable, Equatable {
    var preCurve: CurvePreset = .moderate
    var lutStrength: Double = 92          // 0...100
    var temperature: Double = 0.04        // -1.0...1.0
    var tint: Double = 0.08               // -1.0...1.0
    var shadowTemperature: Double = -0.20 // -1.0...1.0
    var highlightTemperature: Double = 0.25 // -1.0...1.0
    var saturation: Double = 1.0          // 0.0...2.0
    var contrast: Double = 1.04           // 0.0...2.0
    var brightness: Double = 0.0          // -1.0...1.0
    var gamma: Double = 1.01              // 0.0...2.0
    var lutFileName: String = "DJI_DLog_to_Rec709_vivid.cube"

    // MARK: - CodingKeys (映射到 JSON 友好命名)

    enum CodingKeys: String, CodingKey {
        case preCurve, lutStrength, temperature, tint
        case shadowTemperature = "shadow_temp"
        case highlightTemperature = "highlight_temp"
        case saturation, contrast, brightness, gamma
        case lutFileName = "lut_file"
    }
}
