import Foundation

/// 预设持久化管理器
@MainActor
final class PresetStore: ObservableObject {
    @Published var presets: [Preset] = []
    @Published var selectedPresetID: UUID?

    private let fileManager = FileManager.default
    private let presetsDir: URL

    private static let builtInPresetsFileName = "BuiltInPresets.json"

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        presetsDir = appSupport.appendingPathComponent("QuickLUT/presets", isDirectory: true)
        loadAllPresets()
    }

    // MARK: - Public API

    func saveCurrent(as name: String, params: ProcessingParams) {
        let preset = Preset(name: name, params: params, isBuiltIn: false)
        presets.removeAll { $0.name == name && !$0.isBuiltIn }
        presets.append(preset)
        selectedPresetID = preset.id
        persistUserPreset(preset)
    }

    func delete(_ preset: Preset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        if selectedPresetID == preset.id {
            selectedPresetID = presets.first?.id
        }
        let fileURL = presetFileURL(for: preset.id)
        try? fileManager.removeItem(at: fileURL)
    }

    func loadParams(for preset: Preset) -> ProcessingParams {
        preset.params
    }

    // MARK: - Internal

    private func loadAllPresets() {
        var all: [Preset] = []
        all.append(contentsOf: loadBuiltInPresets())
        all.append(contentsOf: loadUserPresets())

        // 去重：用户预设覆盖同名的内置预设
        var seen: [String: Preset] = [:]
        for p in all {
            seen[p.name] = p
        }
        presets = Array(seen.values).sorted { $0.name < $1.name }
        selectedPresetID = presets.first?.id
    }

    private func loadBuiltInPresets() -> [Preset] {
        guard let url = Bundle.main.url(forResource: "BuiltInPresets", withExtension: "json", subdirectory: "Resources") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([BuiltInPresetEntry].self, from: data)
            return decoded.map { entry in
                var params = entry.params
                params.preCurve = CurvePreset(rawValue: entry.params.preCurve.rawValue) ?? .moderate
                return Preset(name: entry.name, params: params, isBuiltIn: true)
            }
        } catch {
            print("加载内置预设失败：\(error)")
            return []
        }
    }

    private func loadUserPresets() -> [Preset] {
        guard fileManager.fileExists(atPath: presetsDir.path) else { return [] }
        do {
            let files = try fileManager.contentsOfDirectory(at: presetsDir, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" }.compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let preset = try? JSONDecoder().decode(Preset.self, from: data) else { return nil }
                return preset
            }
        } catch {
            return []
        }
    }

    private func persistUserPreset(_ preset: Preset) {
        try? fileManager.createDirectory(at: presetsDir, withIntermediateDirectories: true)
        let url = presetFileURL(for: preset.id)
        if let data = try? JSONEncoder().encode(preset) {
            try? data.write(to: url)
        }
    }

    private func presetFileURL(for id: UUID) -> URL {
        presetsDir.appendingPathComponent("\(id.uuidString).json")
    }
}

// MARK: - 内置预设 JSON 解析辅助类型

private struct BuiltInPresetEntry: Codable {
    let name: String
    let params: ProcessingParams
}
