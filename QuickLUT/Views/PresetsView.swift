import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var savePresetName = ""
    @State private var showSaveField = false
    @State private var showDeleteAlert = false
    @State private var presetToDelete: Preset?

    var body: some View {
        HStack(spacing: 6) {
            Picker("预设", selection: Binding<UUID?>(
                get: { viewModel.presetStore.selectedPresetID },
                set: { newID in
                    if let id = newID, let preset = viewModel.presetStore.presets.first(where: { $0.id == id }) {
                        viewModel.applyPreset(preset)
                    }
                }
            )) {
                ForEach(viewModel.presetStore.presets) { preset in
                    Text(preset.name).tag(preset.id as UUID?)
                }
            }
            .frame(maxWidth: .infinity)

            if showSaveField {
                TextField("预设名称", text: $savePresetName, onCommit: {
                    guard !savePresetName.isEmpty else { return }
                    viewModel.saveCurrentPreset(name: savePresetName)
                    savePresetName = ""
                    showSaveField = false
                })
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
            }

            Button(action: {
                if showSaveField {
                    if !savePresetName.isEmpty {
                        viewModel.saveCurrentPreset(name: savePresetName)
                        savePresetName = ""
                    }
                    showSaveField = false
                } else {
                    showSaveField = true
                }
            }) {
                Image(systemName: showSaveField ? "checkmark" : "square.and.arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(showSaveField ? "确认保存" : "保存当前预设")

            Button(action: {
                if let id = viewModel.presetStore.selectedPresetID,
                   let preset = viewModel.presetStore.presets.first(where: { $0.id == id }),
                   !preset.isBuiltIn {
                    presetToDelete = preset
                    showDeleteAlert = true
                }
            }) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(selectedPresetIsBuiltIn)
            .help("删除当前预设")
        }
        .alert("删除预设", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let preset = presetToDelete {
                    viewModel.deletePreset(preset)
                }
            }
        } message: {
            Text("确定要删除\"\(presetToDelete?.name ?? "")\"吗？")
        }
    }

    private var selectedPresetIsBuiltIn: Bool {
        guard let id = viewModel.presetStore.selectedPresetID,
              let preset = viewModel.presetStore.presets.first(where: { $0.id == id }) else { return true }
        return preset.isBuiltIn
    }
}
