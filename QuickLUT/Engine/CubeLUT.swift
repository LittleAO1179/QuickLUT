import Foundation
import simd

/// 解析 Adobe `.cube` LUT 文件，提供三线性采样。
/// 支持 1D / 3D，支持 DOMAIN_MIN / DOMAIN_MAX。
struct CubeLUT {
    let size: Int
    let is3D: Bool
    let domainMin: SIMD3<Float>
    let domainMax: SIMD3<Float>
    /// 3D: size^3 个点，索引 = r + g*size + b*size*size（红色变化最快）
    /// 1D: size 个点
    private let table: [SIMD3<Float>]

    enum ParseError: Error { case unreadable, missingSize, dataCountMismatch }

    init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)

        var size = 0
        var is3D = true
        var dMin = SIMD3<Float>(0, 0, 0)
        var dMax = SIMD3<Float>(1, 1, 1)
        var data: [SIMD3<Float>] = []

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            switch fields[0].uppercased() {
            case "TITLE":
                continue
            case "LUT_3D_SIZE":
                size = Int(fields[1]) ?? 0; is3D = true
            case "LUT_1D_SIZE":
                size = Int(fields[1]) ?? 0; is3D = false
            case "DOMAIN_MIN":
                dMin = SIMD3(Float(fields[1]) ?? 0, Float(fields[2]) ?? 0, Float(fields[3]) ?? 0)
            case "DOMAIN_MAX":
                dMax = SIMD3(Float(fields[1]) ?? 1, Float(fields[2]) ?? 1, Float(fields[3]) ?? 1)
            default:
                // 数据行：三个浮点
                if fields.count >= 3,
                   let r = Float(fields[0]), let g = Float(fields[1]), let b = Float(fields[2]) {
                    data.append(SIMD3(r, g, b))
                }
            }
        }

        guard size > 0 else { throw ParseError.missingSize }
        let expected = is3D ? size * size * size : size
        guard data.count == expected else { throw ParseError.dataCountMismatch }

        self.size = size
        self.is3D = is3D
        self.domainMin = dMin
        self.domainMax = dMax
        self.table = data
    }

    /// 采样：输入/输出均为 0...1 的 RGB
    func sample(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        let span = domainMax - domainMin
        let norm = (rgb - domainMin) / SIMD3(max(span.x, 1e-6), max(span.y, 1e-6), max(span.z, 1e-6))
        let c = simd_clamp(norm, SIMD3(repeating: 0), SIMD3(repeating: 1))
        return is3D ? sample3D(c) : sample1D(c)
    }

    // MARK: - 三线性 3D 采样

    private func sample3D(_ c: SIMD3<Float>) -> SIMD3<Float> {
        let n = size - 1
        let pos = c * Float(n)
        let i0 = SIMD3<Int>(Int(pos.x.rounded(.down)), Int(pos.y.rounded(.down)), Int(pos.z.rounded(.down)))
        let i1 = SIMD3<Int>(min(i0.x + 1, n), min(i0.y + 1, n), min(i0.z + 1, n))
        let f = pos - SIMD3(Float(i0.x), Float(i0.y), Float(i0.z))

        func at(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Float> {
            table[r + g * size + b * size * size]
        }

        let c000 = at(i0.x, i0.y, i0.z), c100 = at(i1.x, i0.y, i0.z)
        let c010 = at(i0.x, i1.y, i0.z), c110 = at(i1.x, i1.y, i0.z)
        let c001 = at(i0.x, i0.y, i1.z), c101 = at(i1.x, i0.y, i1.z)
        let c011 = at(i0.x, i1.y, i1.z), c111 = at(i1.x, i1.y, i1.z)

        let c00 = mix(c000, c100, f.x), c10 = mix(c010, c110, f.x)
        let c01 = mix(c001, c101, f.x), c11 = mix(c011, c111, f.x)
        let c0 = mix(c00, c10, f.y), c1 = mix(c01, c11, f.y)
        return mix(c0, c1, f.z)
    }

    // MARK: - 线性 1D 采样（逐通道，三列分别是 R/G/B 映射）

    private func sample1D(_ c: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(lerp1D(c.x, channel: 0), lerp1D(c.y, channel: 1), lerp1D(c.z, channel: 2))
    }

    private func lerp1D(_ x: Float, channel: Int) -> Float {
        let n = size - 1
        let pos = x * Float(n)
        let i0 = Int(pos.rounded(.down))
        let i1 = min(i0 + 1, n)
        let f = pos - Float(i0)
        let v0 = table[i0][channel], v1 = table[i1][channel]
        return v0 + (v1 - v0) * f
    }

    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }
}
