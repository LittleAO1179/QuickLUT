import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.gray.opacity(0.04))
                    )

                VStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.system(size: 28))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)
                    Text("拖入视频文件或点击选择")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
            }
            .frame(height: 70)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .onTapGesture {
                openFileBrowser()
            }

            if let fileURL = viewModel.selectedFileURL {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let outputURL = viewModel.outputURL {
                    HStack {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(outputURL.lastPathComponent)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            if let urlData = data as? Data,
               let path = String(data: urlData, encoding: .utf8),
               let url = URL(string: path) {
                DispatchQueue.main.async {
                    viewModel.selectFile(url)
                }
            }
        }
        return true
    }

    private func openFileBrowser() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie, .avi, .video]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectFile(url)
        }
    }
}
