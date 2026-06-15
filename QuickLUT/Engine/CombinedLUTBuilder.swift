import Foundation
import simd

/// 把整条像素链路（curves → lut3d+strength → colorbalance → eq）烘焙成一张合并 3D LUT 数据，
/// 供 GPU 端 `CIColorCube` 一次查表即可完成全部调色。
enum CombinedLUTBuilder {

    /// LUT 网格分辨率（每维点数）。33 与常见 .cube 一致，精度足够。
    static let cubeSize = 33

    /// 生成 CIColorCube 所需数据：size^3 个 RGBA(Float32)，红色索引变化最快。
    static func bakeCubeData(params: ProcessingParams, lut: CubeLUT, size: Int) -> Data {
        let spline = params.preCurve.ffmpegCurveDefinition.flatMap { NaturalCubicSpline(curveDefinition: $0) }
        let strength = Float(min(params.lutStrength, 100) / 100.0)

        let cbOffsets = ColorBalanceBuilder.offsets(
            temperature: params.temperature,
            tint: params.tint,
            shadowTemp: params.shadowTemperature,
            highlightTemp: params.highlightTemperature
        )
        let eqParams = Eq.Params(
            saturation: Float(params.saturation),
            contrast: Float(params.contrast),
            brightness: Float(params.brightness),
            gamma: Float(params.gamma)
        )

        let denom = Float(size - 1)
        var floats = [Float](repeating: 0, count: size * size * size * 4)
        var idx = 0

        for bi in 0..<size {
            let b = Float(bi) / denom
            for gi in 0..<size {
                let g = Float(gi) / denom
                for ri in 0..<size {
                    let r = Float(ri) / denom
                    var c = SIMD3<Float>(r, g, b)

                    if let spline = spline {
                        c = SIMD3(spline.eval(c.x), spline.eval(c.y), spline.eval(c.z))
                    }

                    let lutColor = lut.sample(c)
                    c = strength >= 1 ? lutColor : c + (lutColor - c) * strength

                    if !cbOffsets.isIdentity {
                        c = ColorBalance.apply(c, cbOffsets)
                    }
                    if !eqParams.isIdentity {
                        c = Eq.apply(c, eqParams)
                    }

                    floats[idx + 0] = c.x
                    floats[idx + 1] = c.y
                    floats[idx + 2] = c.z
                    floats[idx + 3] = 1
                    idx += 4
                }
            }
        }

        return floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
