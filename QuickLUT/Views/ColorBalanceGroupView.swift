import SwiftUI

struct ColorBalanceGroupView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        GroupBox(label: Text("白平衡 / 分色")) {
            VStack(spacing: 6) {
                ParamSliderRow(
                    label: "色温",
                    keyPath: \.temperature,
                    range: -1.0...1.0,
                    step: 0.01,
                    format: "%+.2f",
                    hint: "冷 → 暖"
                )
                ParamSliderRow(
                    label: "色调",
                    keyPath: \.tint,
                    range: -1.0...1.0,
                    step: 0.01,
                    format: "%+.2f",
                    hint: "绿 → 洋红"
                )
                ParamSliderRow(
                    label: "阴影",
                    keyPath: \.shadowTemperature,
                    range: -1.0...1.0,
                    step: 0.01,
                    format: "%+.2f",
                    hint: "青 → 暖"
                )
                ParamSliderRow(
                    label: "高光",
                    keyPath: \.highlightTemperature,
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

/// 参数滑块：本地 @State 驱动 Slider 显示，避免自定义 Binding 导致滑块/数字不刷新。
struct ParamSliderRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let label: String
    let keyPath: WritableKeyPath<ProcessingParams, Double>
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var hint: String = ""
    var labelWidth: CGFloat = 36

    @State private var localValue: Double = 0

    private var modelValue: Double { viewModel.params[keyPath: keyPath] }

    var body: some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .frame(width: labelWidth, alignment: .leading)
            }
            Slider(value: $localValue, in: range, step: step)
                .onChange(of: localValue) { _, newValue in
                    if newValue != viewModel.params[keyPath: keyPath] {
                        viewModel.setParam(keyPath, newValue)
                    }
                }
            Text(String(format: format, localValue))
                .frame(width: 42, alignment: .trailing)
                .font(.caption.monospacedDigit())
            if !hint.isEmpty {
                Text(hint)
                    .frame(width: 40, alignment: .leading)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { localValue = modelValue }
        .onChange(of: viewModel.params) { _, newParams in
            let v = newParams[keyPath: keyPath]
            if v != localValue { localValue = v }
        }
    }
}
