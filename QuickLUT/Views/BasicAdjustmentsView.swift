import SwiftUI

struct BasicAdjustmentsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        GroupBox(label: Text("基础调整")) {
            VStack(spacing: 6) {
                HStack {
                    Text("饱和度")
                        .frame(width: 50, alignment: .leading)
                    Slider(value: $viewModel.params.saturation, in: 0.0...2.0, step: 0.01)
                    Text(String(format: "%.2f", viewModel.params.saturation))
                        .frame(width: 42, alignment: .trailing)
                        .font(.caption.monospacedDigit())
                }
                HStack {
                    Text("对比度")
                        .frame(width: 50, alignment: .leading)
                    Slider(value: $viewModel.params.contrast, in: 0.0...2.0, step: 0.01)
                    Text(String(format: "%.2f", viewModel.params.contrast))
                        .frame(width: 42, alignment: .trailing)
                        .font(.caption.monospacedDigit())
                }
                HStack {
                    Text("亮度")
                        .frame(width: 50, alignment: .leading)
                    Slider(value: $viewModel.params.brightness, in: -1.0...1.0, step: 0.01)
                    Text(String(format: "%+.2f", viewModel.params.brightness))
                        .frame(width: 42, alignment: .trailing)
                        .font(.caption.monospacedDigit())
                }
                HStack {
                    Text("Gamma")
                        .frame(width: 50, alignment: .leading)
                    Slider(value: $viewModel.params.gamma, in: 0.0...2.0, step: 0.01)
                    Text(String(format: "%.2f", viewModel.params.gamma))
                        .frame(width: 42, alignment: .trailing)
                        .font(.caption.monospacedDigit())
                }
            }
        }
        .font(.caption)
    }
}
