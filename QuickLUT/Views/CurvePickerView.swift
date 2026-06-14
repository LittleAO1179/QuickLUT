import SwiftUI

struct CurvePickerView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("曲线")
                    .frame(width: 70, alignment: .leading)
                Picker("", selection: $viewModel.params.preCurve) {
                    ForEach(CurvePreset.allCases, id: \.self) { curve in
                        Text(curve.displayName).tag(curve)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Text("LUT 强度")
                    .frame(width: 70, alignment: .leading)
                Slider(
                    value: $viewModel.params.lutStrength,
                    in: 0...100,
                    step: 1
                )
                Text("\(Int(viewModel.params.lutStrength))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}
