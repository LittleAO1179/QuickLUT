import SwiftUI

struct CurvePickerView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.rowSpacing) {
            HStack(spacing: LayoutMetrics.rowSpacing) {
                Text("曲线")
                    .frame(width: LayoutMetrics.labelWidth, alignment: .leading)
                Picker("", selection: $viewModel.params.preCurve) {
                    ForEach(CurvePreset.allCases, id: \.self) { curve in
                        Text(curve.displayName).tag(curve)
                    }
                }
                .labelsHidden()
                Spacer()
                    .frame(width: LayoutMetrics.valueWidth)
            }

            LabeledSlider(label: "LUT 强度", value: $viewModel.params.lutStrength,
                          range: 0...100, step: 1, isPercent: true, defaultValue: 92,
                          trackGradient: LinearGradient(colors: [Color.blue.opacity(0.3), .blue], startPoint: .leading, endPoint: .trailing))
        }
    }
}
