import Foundation

/// 移植自 color_ai.py 的 build_filter_chain() 函数
/// 构建完整的 ffmpeg filter_complex 字符串
enum FilterChainBuilder {

    /// 构建 filter_complex 链
    /// - 处理链: curves → split → lut3d → blend → colorbalance → eq → [out]
    static func build(
        params: ProcessingParams,
        lutFilePath: String,
        scale: String? = nil
    ) -> String {
        var parts: [String] = []
        var current = "0:v"

        // 1. Pre-LUT 曲线
        if let curveDef = params.preCurve.ffmpegCurveDefinition {
            parts.append("[\(current)]curves=all='\(curveDef)'[pre]")
            current = "pre"
        }

        // 2. LUT 混合
        let lutStrength = params.lutStrength
        if lutStrength < 100 {
            parts.append("[\(current)]split[orig][for_lut]")
            parts.append("[for_lut]lut3d='\(lutFilePath)':interp=trilinear[lut_out]")
            let origRatio = (100.0 - lutStrength) / 100.0
            parts.append("[orig][lut_out]blend=all_mode=normal:all_opacity=\(String(format: "%.4f", origRatio))[blended]")
            current = "blended"
        } else {
            parts.append("[\(current)]lut3d='\(lutFilePath)':interp=trilinear[lut_out]")
            current = "lut_out"
        }

        // 3. 白平衡 + 分色
        if let cb = ColorBalanceBuilder.build(
            temperature: params.temperature,
            tint: params.tint,
            shadowTemp: params.shadowTemperature,
            highlightTemp: params.highlightTemperature
        ) {
            parts.append("[\(current)]colorbalance=\(cb)[color_balanced]")
            current = "color_balanced"
        }

        // 4. Post eq
        var eqParts: [String] = []
        if params.saturation != 1.0 { eqParts.append("saturation=\(params.saturation)") }
        if params.contrast != 1.0 { eqParts.append("contrast=\(params.contrast)") }
        if params.brightness != 0.0 { eqParts.append("brightness=\(params.brightness)") }
        if params.gamma != 1.0 { eqParts.append("gamma=\(params.gamma)") }
        if !eqParts.isEmpty {
            parts.append("[\(current)]eq=\(eqParts.joined(separator: ":"))[eq_out]")
            current = "eq_out"
        }

        // 5. 终结
        if let scale = scale {
            parts.append("[\(current)]scale=\(scale)[out]")
        } else {
            parts.append("[\(current)]null[out]")
        }

        return parts.joined(separator: ";")
    }
}
