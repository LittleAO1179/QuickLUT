import SwiftUI

struct EncodingProgressView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        switch viewModel.job.status {
        case .idle:
            EmptyView()

        case .preparing:
            HStack {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
                Text("准备中...")
                    .font(.caption)
                Spacer()
            }

        case .encoding(let progress):
            VStack(spacing: 4) {
                ProgressView(value: progress, total: 1.0)
                HStack {
                    Text("编码中...")
                        .font(.caption2)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.monospacedDigit())
                }
                Button("取消") {
                    viewModel.cancelEncoding()
                }
                .buttonStyle(.borderless)
                .font(.caption2)
            }

        case .completed(let path):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("完成！")
                    .font(.caption)
                Spacer()
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
                .buttonStyle(.link)
                .font(.caption2)
            }

        case .failed(let error):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
                Spacer()
            }

        case .cancelled:
            HStack {
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.orange)
                Text("已取消")
                    .font(.caption)
                Spacer()
            }
        }
    }
}
