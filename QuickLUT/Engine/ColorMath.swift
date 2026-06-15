import Foundation
import simd

// MARK: - 自然三次样条（对应 ffmpeg curves 的默认插值）

/// 通过若干控制点的自然三次样条，eval 结果裁剪到 0...1。
struct NaturalCubicSpline {
    private let xs: [Float]
    private let ys: [Float]
    private let m: [Float]  // 各点二阶导

    /// 从 ffmpeg curves 定义串解析，如 "0/0.03 0.2/0.24 0.5/0.5 0.8/0.76 1/0.94"
    init?(curveDefinition def: String) {
        var px: [Float] = [], py: [Float] = []
        for pair in def.split(separator: " ") {
            let kv = pair.split(separator: "/")
            guard kv.count == 2, let x = Float(kv[0]), let y = Float(kv[1]) else { return nil }
            px.append(x); py.append(y)
        }
        guard px.count >= 2 else { return nil }
        self.init(xs: px, ys: py)
    }

    init(xs: [Float], ys: [Float]) {
        self.xs = xs
        self.ys = ys
        self.m = Self.solveSecondDerivatives(xs: xs, ys: ys)
    }

    /// 自然边界条件（端点二阶导为 0），解三对角方程。
    private static func solveSecondDerivatives(xs: [Float], ys: [Float]) -> [Float] {
        let n = xs.count
        if n < 3 { return [Float](repeating: 0, count: n) }

        var h = [Float](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) { h[i] = xs[i + 1] - xs[i] }

        var alpha = [Float](repeating: 0, count: n)
        for i in 1..<(n - 1) {
            alpha[i] = 3 * ((ys[i + 1] - ys[i]) / h[i] - (ys[i] - ys[i - 1]) / h[i - 1])
        }

        var l = [Float](repeating: 0, count: n)
        var mu = [Float](repeating: 0, count: n)
        var z = [Float](repeating: 0, count: n)
        l[0] = 1
        for i in 1..<(n - 1) {
            l[i] = 2 * (xs[i + 1] - xs[i - 1]) - h[i - 1] * mu[i - 1]
            mu[i] = h[i] / l[i]
            z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i]
        }
        l[n - 1] = 1

        var c = [Float](repeating: 0, count: n)
        for j in stride(from: n - 2, through: 0, by: -1) {
            c[j] = z[j] - mu[j] * c[j + 1]
        }
        return c
    }

    func eval(_ x: Float) -> Float {
        let clampedX = simd_clamp(x, xs.first!, xs.last!)
        // 定位区间
        var i = xs.count - 2
        for k in 0..<(xs.count - 1) where clampedX <= xs[k + 1] { i = k; break }

        let h = xs[i + 1] - xs[i]
        let dx = clampedX - xs[i]
        let a = ys[i]
        let b = (ys[i + 1] - ys[i]) / h - h * (2 * m[i] + m[i + 1]) / 3
        let cc = m[i]
        let d = (m[i + 1] - m[i]) / (3 * h)
        let y = a + b * dx + cc * dx * dx + d * dx * dx * dx
        return simd_clamp(y, 0, 1)
    }
}

// MARK: - colorbalance（移植自 ffmpeg vf_colorbalance）

enum ColorBalance {
    /// 单通道：v 为通道值，l 为整像素明度 max(r,g,b)+min(r,g,b)（0..2，三通道共用），与 ffmpeg 一致
    static func component(_ v: Float, lightness l: Float, shadows s: Float, midtones m: Float, highlights h: Float) -> Float {
        let a: Float = 4, b: Float = 0.333, scale: Float = 0.7
        let ss = s * simd_clamp((b - l) * a + 0.5, 0, 1) * scale
        let mm = m * simd_clamp((l - b) * a + 0.5, 0, 1) * simd_clamp((1 - l - b) * a + 0.5, 0, 1) * scale
        let hh = h * simd_clamp((l - 1 + b) * a + 0.5, 0, 1) * scale
        return simd_clamp(v + ss + mm + hh, 0, 1)
    }

    /// 偏移量集合（与 ColorBalanceBuilder 的 rs/rm/rh... 对应）
    struct Offsets {
        var rs: Float = 0, rm: Float = 0, rh: Float = 0
        var gs: Float = 0, gm: Float = 0, gh: Float = 0
        var bs: Float = 0, bm: Float = 0, bh: Float = 0
        var isIdentity: Bool {
            rs == 0 && rm == 0 && rh == 0 && gs == 0 && gm == 0 && gh == 0 && bs == 0 && bm == 0 && bh == 0
        }
    }

    static func apply(_ rgb: SIMD3<Float>, _ o: Offsets) -> SIMD3<Float> {
        let l = max(rgb.x, max(rgb.y, rgb.z)) + min(rgb.x, min(rgb.y, rgb.z))
        return SIMD3(
            component(rgb.x, lightness: l, shadows: o.rs, midtones: o.rm, highlights: o.rh),
            component(rgb.y, lightness: l, shadows: o.gs, midtones: o.gm, highlights: o.gh),
            component(rgb.z, lightness: l, shadows: o.bs, midtones: o.bm, highlights: o.bh)
        )
    }
}

// MARK: - eq（移植自 ffmpeg vf_eq：YUV 域，对比度/亮度/gamma 作用于 Y，饱和度作用于 UV）

enum Eq {
    struct Params {
        var saturation: Float = 1
        var contrast: Float = 1
        var brightness: Float = 0
        var gamma: Float = 1
        var isIdentity: Bool { saturation == 1 && contrast == 1 && brightness == 0 && gamma == 1 }
    }

    static func apply(_ rgb: SIMD3<Float>, _ p: Params) -> SIMD3<Float> {
        // Rec.709 RGB -> YUV(Cb,Cr 居中于 0)
        let y0 = 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z
        let u0 = (rgb.z - y0) / 1.8556
        let v0 = (rgb.x - y0) / 1.5748

        // Y: 对比度 + 亮度 + gamma
        var y = p.contrast * (y0 - 0.5) + 0.5 + p.brightness
        if y <= 0 { y = 0 } else { y = simd_clamp(pow(y, 1 / p.gamma), 0, 1) }

        // 饱和度作用于色度
        let u = u0 * p.saturation
        let v = v0 * p.saturation

        let r = y + 1.5748 * v
        let g = y - 0.1873 * u - 0.4681 * v
        let b = y + 1.8556 * u
        return simd_clamp(SIMD3(r, g, b), SIMD3(repeating: 0), SIMD3(repeating: 1))
    }
}
