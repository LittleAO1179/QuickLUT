import SwiftUI

struct ColorBalanceGroupView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        CollapsibleSection("白平衡 / 分色", key: "colorBalance") {
            LabeledSlider(label: "色温", value: $viewModel.params.temperature,
                          range: -1...1, format: "%+.2f", defaultValue: 0.04,
                          trackGradient: LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing))
            LabeledSlider(label: "色调", value: $viewModel.params.tint,
                          range: -1...1, format: "%+.2f", defaultValue: 0.08,
                          trackGradient: LinearGradient(colors: [.green, .purple], startPoint: .leading, endPoint: .trailing))
            LabeledSlider(label: "阴影", value: $viewModel.params.shadowTemperature,
                          range: -1...1, format: "%+.2f", defaultValue: -0.20,
                          trackGradient: LinearGradient(colors: [.cyan, .orange], startPoint: .leading, endPoint: .trailing))
            LabeledSlider(label: "高光", value: $viewModel.params.highlightTemperature,
                          range: -1...1, format: "%+.2f", defaultValue: 0.25,
                          trackGradient: LinearGradient(colors: [.blue, .yellow], startPoint: .leading, endPoint: .trailing))
        }
    }
}
