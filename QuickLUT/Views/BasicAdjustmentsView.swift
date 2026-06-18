import SwiftUI

struct BasicAdjustmentsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        CollapsibleSection("基础调整", key: "basicAdjustments") {
            LabeledSlider(label: "饱和度", value: $viewModel.params.saturation,
                          range: 0...2, format: "%.2f", defaultValue: 1.0,
                          trackGradient: LinearGradient(colors: [Color(white: 0.6), .blue], startPoint: .leading, endPoint: .trailing))
            LabeledSlider(label: "对比度", value: $viewModel.params.contrast,
                          range: 0...2, format: "%.2f", defaultValue: 1.04,
                          trackGradient: LinearGradient(colors: [Color(white: 0.55), Color(white: 0.05)], startPoint: .leading, endPoint: .trailing))
            LabeledSlider(label: "亮度", value: $viewModel.params.brightness,
                          range: -1...1, format: "%+.2f", defaultValue: 0.0,
                          trackGradient: LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing))
            LabeledSlider(label: "Gamma", value: $viewModel.params.gamma,
                          range: 0...2, format: "%.2f", defaultValue: 1.01,
                          trackGradient: LinearGradient(colors: [Color(white: 0.2), Color(white: 0.9)], startPoint: .leading, endPoint: .trailing))
        }
    }
}
