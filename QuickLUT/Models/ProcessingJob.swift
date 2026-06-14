import Foundation

/// 编码任务状态
struct ProcessingJob: Identifiable {
    enum Status: Equatable {
        case idle
        case preparing
        case encoding(progress: Double)  // 0.0...1.0
        case completed(outputPath: String)
        case failed(error: String)
        case cancelled

        var isActive: Bool {
            switch self {
            case .preparing, .encoding: return true
            default: return false
            }
        }
    }

    let id: UUID
    var inputURL: URL?
    var outputURL: URL?
    var status: Status = .idle

    init(url: URL? = nil) {
        self.id = UUID()
        self.inputURL = url
    }
}
