import Foundation

/// 移植自 color_ai.py 的 make_colorbalance() 函数
/// 将色温/色调/分色参数映射为 ffmpeg colorbalance 滤镜字符串
enum ColorBalanceBuilder {

    /// 生成 colorbalance 参数字符串
    /// - 返回格式: "rs=0.040:rh=0.024:bs=-0.040:bh=-0.024"，所有值为零时返回 nil
    static func build(
        temperature: Double,
        tint: Double,
        shadowTemp: Double,
        highlightTemp: Double
    ) -> String? {
        var parts: [String: Double] = [:]

        /// 辅助：叠加数值
        func add(_ key: String, _ value: Double) {
            parts[key] = (parts[key] ?? 0) + value
        }

        // --- 整体色温 ---
        if temperature != 0 {
            if temperature > 0 {
                add("rs", 0.20 * temperature)
                add("rh", 0.12 * temperature)
                add("bs", -0.20 * temperature)
                add("bh", -0.12 * temperature)
            } else {
                let s = -temperature
                add("rs", -0.20 * s)
                add("rh", -0.12 * s)
                add("bs", 0.20 * s)
                add("bh", 0.12 * s)
            }
        }

        // --- 色调（绿/洋红） ---
        if tint != 0 {
            if tint > 0 {
                add("gs", -0.30 * tint)
                add("gh", -0.15 * tint)
            } else {
                let s = -tint
                add("gs", 0.30 * s)
                add("gh", 0.15 * s)
            }
        }

        // --- 阴影分色 ---
        if shadowTemp != 0 {
            if shadowTemp > 0 {
                add("rs", 0.25 * shadowTemp)
                add("bs", -0.25 * shadowTemp)
            } else {
                let s = -shadowTemp
                add("rs", -0.20 * s)  // 减红 = 青
                add("bs", 0.25 * s)   // 加蓝
                add("gs", 0.08 * s)   // 微加绿 = 青色调
            }
        }

        // --- 高光分色 ---
        if highlightTemp != 0 {
            if highlightTemp > 0 {
                add("rh", 0.20 * highlightTemp)
                add("bh", -0.20 * highlightTemp)
                add("gh", -0.05 * highlightTemp)  // 减绿 = 偏橙
            } else {
                let s = -highlightTemp
                add("rh", -0.20 * s)
                add("bh", 0.20 * s)
            }
        }

        guard !parts.isEmpty else { return nil }

        return parts
            .sorted { $0.key < $1.key }
            .map { String(format: "%@=%.3f", $0.key, $0.value) }
            .joined(separator: ":")
    }

    /// 原生管线用：直接返回 colorbalance 偏移量（与 build 字符串同一套映射）
    static func offsets(
        temperature: Double,
        tint: Double,
        shadowTemp: Double,
        highlightTemp: Double
    ) -> ColorBalance.Offsets {
        var o = ColorBalance.Offsets()

        if temperature > 0 {
            o.rs += Float(0.20 * temperature); o.rh += Float(0.12 * temperature)
            o.bs += Float(-0.20 * temperature); o.bh += Float(-0.12 * temperature)
        } else if temperature < 0 {
            let s = -temperature
            o.rs += Float(-0.20 * s); o.rh += Float(-0.12 * s)
            o.bs += Float(0.20 * s); o.bh += Float(0.12 * s)
        }

        if tint > 0 {
            o.gs += Float(-0.30 * tint); o.gh += Float(-0.15 * tint)
        } else if tint < 0 {
            let s = -tint
            o.gs += Float(0.30 * s); o.gh += Float(0.15 * s)
        }

        if shadowTemp > 0 {
            o.rs += Float(0.25 * shadowTemp); o.bs += Float(-0.25 * shadowTemp)
        } else if shadowTemp < 0 {
            let s = -shadowTemp
            o.rs += Float(-0.20 * s); o.bs += Float(0.25 * s); o.gs += Float(0.08 * s)
        }

        if highlightTemp > 0 {
            o.rh += Float(0.20 * highlightTemp); o.bh += Float(-0.20 * highlightTemp); o.gh += Float(-0.05 * highlightTemp)
        } else if highlightTemp < 0 {
            let s = -highlightTemp
            o.rh += Float(-0.20 * s); o.bh += Float(0.20 * s)
        }

        return o
    }
}
