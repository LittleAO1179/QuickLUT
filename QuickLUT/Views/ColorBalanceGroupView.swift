import SwiftUI

struct ColorBalanceGroupView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        GroupBox(label: Text("白平衡 / 分色")) {
            VStack(spacing: 6) {
                SliderRow(
                    label: "色温",
                    value: $viewModel.params.temperature,
                    range: -1.0...1.0,
                    step: 0.01,
                    format: "%+.2f",
                    hint: "冷 → 暖"
                )
                SliderRow(
                    label: "色调",
                    value: $viewModel.params.tint,
                    range: -1.0...1.0,
                    step: 0.01,
                    format: "%+.2f",
                    hint: "绿 → 洋红"
                )
                SliderRow(
                    label: "阴影",
                    value: $viewModel.params.shadowTemperature,
                    range: -1.0...1.0,
                    step: 0.01,
                    format: "%+.2f",
                    hint: "青 → 暖"
                )
                SliderRow(
                    label: "高光",
                    value: $viewModel.params.highlightTemperature,
                    range: -1.0...1.0,
                    step: 0.01,
                    format: "%+.2f",
                    hint: "冷 → 金"
                )
            }
        }
        .font(.caption)
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let hint: String

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 36, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text(String(format: format, value))
                .frame(width: 42, alignment: .trailing)
                .font(.caption.monospacedDigit())
            Text(hint)
                .frame(width: 40, alignment: .leading)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
