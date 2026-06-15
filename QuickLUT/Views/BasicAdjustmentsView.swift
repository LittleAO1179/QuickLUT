import SwiftUI

struct BasicAdjustmentsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        GroupBox(label: Text("基础调整")) {
            VStack(spacing: 6) {
                ParamSliderRow(label: "饱和度", keyPath: \.saturation, range: 0.0...2.0, step: 0.01, format: "%.2f", labelWidth: 50)
                ParamSliderRow(label: "对比度", keyPath: \.contrast, range: 0.0...2.0, step: 0.01, format: "%.2f", labelWidth: 50)
                ParamSliderRow(label: "亮度", keyPath: \.brightness, range: -1.0...1.0, step: 0.01, format: "%+.2f", labelWidth: 50)
                ParamSliderRow(label: "Gamma", keyPath: \.gamma, range: 0.0...2.0, step: 0.01, format: "%.2f", labelWidth: 50)
            }
        }
        .font(.caption)
    }
}
