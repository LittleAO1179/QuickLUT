import SwiftUI

struct PopoverContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PresetsView()
                Divider()
                DropZoneView()
                LUTPickerView()
                CurvePickerView()
                ColorBalanceGroupView()
                BasicAdjustmentsView()

                if !isIdle {
                    EncodingProgressView()
                }

                if isIdle || isTerminalState {
                    Button(action: viewModel.startEncoding) {
                        Text("开始编码")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.selectedFileURL == nil)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding()
        }
        .frame(width: 360)
        .frame(minHeight: 400, maxHeight: 600)
        .environmentObject(viewModel)
    }

    private var isIdle: Bool {
        viewModel.job.status == .idle
    }

    private var isTerminalState: Bool {
        if case .completed = viewModel.job.status { return true }
        if case .failed = viewModel.job.status { return true }
        if case .cancelled = viewModel.job.status { return true }
        return false
    }
}
