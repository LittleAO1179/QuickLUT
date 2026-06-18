import SwiftUI

struct PopoverContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: LayoutMetrics.sectionSpacing) {
            PresetsView()
            Divider()
            DropZoneView()
            LUTPickerView()
            CurvePickerView()
            ColorBalanceGroupView()
            BasicAdjustmentsView()

            // 预览按钮 + 预览图
            if viewModel.selectedFileURL != nil {
                previewSection
            }

            // 编码状态
            if !isIdle {
                EncodingProgressView()
            }

            // 开始编码按钮
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
        .frame(width: LayoutMetrics.contentWidth)
        .fixedSize(horizontal: false, vertical: true)
        .environmentObject(viewModel)
    }

    // MARK: - 预览区域

    private var previewSection: some View {
        VStack(spacing: 8) {
            Button(action: viewModel.generatePreview) {
                HStack(spacing: 4) {
                    if viewModel.isGeneratingPreview {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "eye")
                            .font(.caption)
                    }
                    Text(viewModel.isGeneratingPreview ? "生成中..." : "预览效果")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isGeneratingPreview)

            if let previewURL = viewModel.previewImageURL {
                if let nsImage = NSImage(contentsOf: previewURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
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
