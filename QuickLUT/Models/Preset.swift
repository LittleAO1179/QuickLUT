import Foundation

/// 预设：一组命名并保存的调色参数
struct Preset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var params: ProcessingParams
    var isBuiltIn: Bool

    init(name: String, params: ProcessingParams, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.params = params
        self.isBuiltIn = isBuiltIn
    }
}
