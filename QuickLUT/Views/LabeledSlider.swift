import SwiftUI

/// 自定义渐变滑块：渐变轨道 + 可拖拽圆形滑块
struct GradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01
    let gradient: LinearGradient

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let thumbSize: CGFloat = 14
            let trackWidth = geo.size.width - thumbSize

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(gradient)
                    .frame(height: 4)

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 0.5)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .frame(width: thumbSize, height: thumbSize)
                    .scaleEffect(isDragging ? 1.15 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: isDragging)
                    .offset(x: thumbX(trackWidth: trackWidth, thumbSize: thumbSize))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let fraction = max(0, min(1, (gesture.location.x - thumbSize / 2) / trackWidth))
                        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                        value = (raw / step).rounded() * step
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 22)
    }

    private func thumbX(trackWidth: CGFloat, thumbSize: CGFloat) -> CGFloat {
        let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return trackWidth * CGFloat(fraction)
    }
}

/// 统一滑块行：左对齐标签 + 渐变滑块 + 可编辑数值
struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01
    var format: String = "%.2f"
    var isPercent: Bool = false
    var defaultValue: Double = 0
    var trackGradient: LinearGradient? = nil

    var body: some View {
        HStack(spacing: LayoutMetrics.rowSpacing) {
            Text(label)
                .frame(width: LayoutMetrics.labelWidth, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { value = defaultValue }

            if let gradient = trackGradient {
                GradientSlider(value: $value, range: range, step: step, gradient: gradient)
            } else {
                Slider(value: $value, in: range, step: step)
            }

            EditableValueField(value: $value, range: range, format: format, isPercent: isPercent)
        }
    }
}
