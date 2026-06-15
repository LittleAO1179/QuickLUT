import SwiftUI

struct CurvePickerView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("曲线")
                    .frame(width: 70, alignment: .leading)
                Picker("", selection: Binding(
                    get: { viewModel.params.preCurve },
                    set: { viewModel.applyCurve($0) }
                )) {
                    ForEach(CurvePreset.allCases, id: \.self) { curve in
                        Text(curve.displayName).tag(curve)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Text("LUT 强度")
                    .frame(width: 70, alignment: .leading)
                ParamSliderRow(
                    label: "",
                    keyPath: \.lutStrength,
                    range: 0...100,
                    step: 1,
                    format: "%.0f%%",
                    labelWidth: 0
                )
            }
        }
    }
}
