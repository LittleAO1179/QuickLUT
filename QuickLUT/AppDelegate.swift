import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 透明的拖放/点击覆盖层
// 图标由 NSStatusItem.button 渲染（稳定显示），本视图仅覆盖在 button 上方
// 负责处理拖放与左右键点击。

final class DropStatusBarView: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onDropFile: ((URL) -> Void)?

    private let highlightLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // 高亮层（拖放反馈）
        highlightLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        highlightLayer.cornerRadius = 4
        highlightLayer.opacity = 0
        layer?.addSublayer(highlightLayer)

        // 注册拖放类型
        registerForDraggedTypes([.fileURL])
    }

    override func layout() {
        super.layout()
        highlightLayer.frame = bounds
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    // MARK: - 拖放

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasVideoFile(sender) else { return [] }
        highlightLayer.opacity = 1
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlightLayer.opacity = 0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        highlightLayer.opacity = 0
        guard let url = extractFileURL(sender) else { return false }
        onDropFile?(url)
        return true
    }

    private func hasVideoFile(_ sender: NSDraggingInfo) -> Bool {
        extractFileURL(sender) != nil
    }

    private func extractFileURL(_ sender: NSDraggingInfo) -> URL? {
        let types: [UTType] = [.mpeg4Movie, .quickTimeMovie, .movie, .avi, .video]
        let extensions = ["mp4", "mov", "mxf", "avi", "mkv", "webm", "m4v"]

        guard let pasteboardItem = sender.draggingPasteboard.pasteboardItems?.first else {
            return nil
        }

        // 尝试通过 UTType 获取
        for type in types {
            if let data = pasteboardItem.data(forType: NSPasteboard.PasteboardType(type.identifier)),
               let path = String(data: data, encoding: .utf8) {
                let url = URL(fileURLWithPath: path)
                if extensions.contains(url.pathExtension.lowercased()) {
                    return url
                }
            }
        }

        // 回退：直接从 fileURL 获取
        if let data = pasteboardItem.data(forType: .fileURL),
           let path = String(data: data, encoding: .utf8) {
            let url = URL(fileURLWithPath: path)
            if extensions.contains(url.pathExtension.lowercased()) {
                return url
            }
        }

        return nil
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var dropView: DropStatusBarView!
    let viewModel = AppViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标：图标交给 button 渲染（稳定显示），拖放/点击用覆盖层处理
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let button = statusItem.button!
        let icon = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "QuickLUT")
        icon?.isTemplate = true
        button.image = icon

        dropView = DropStatusBarView(frame: button.bounds)
        dropView.autoresizingMask = [.width, .height]
        dropView.onClick = { [weak self] in self?.togglePopover() }
        dropView.onRightClick = { [weak self] in self?.showStatusBarMenu() }
        dropView.onDropFile = { [weak self] url in
            self?.viewModel.selectFile(url)
            self?.showPopover()
        }
        button.addSubview(dropView)

        // 创建 Popover（applicationDefined 模式：不自动关闭，手动管理）
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView().environmentObject(viewModel)
        )

        // 监听鼠标点击：点击 popover 窗口外部时关闭
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  self.popover.isShown,
                  let popoverWindow = self.popover.contentViewController?.view.window,
                  let dropView = self.dropView else {
                return event
            }
            // 不关闭的情况：点击 popover 内部 或 点击状态栏图标
            if event.window === popoverWindow { return event }
            let pointInDropView = dropView.convert(event.locationInWindow, from: nil)
            if dropView.bounds.contains(pointInDropView) { return event }

            self.popover.performClose(nil)
            return event
        }

        // 监听 Esc 键关闭
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.popover.isShown,
                  event.keyCode == 53 else { return event }
            self.popover.performClose(nil)
            return nil
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - 右键菜单

    private func showStatusBarMenu() {
        let menu = buildStatusBarMenu()
        // 在状态栏图标位置弹出菜单
        let location = dropView.bounds.origin
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: location.x, y: location.y - 2),
            in: dropView
        )
    }

    /// 构建右键菜单（便于后续扩展，在这里添加新菜单项即可）
    private func buildStatusBarMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = true

        // --- 功能菜单项区域（在此之上添加新功能） ---

        // 分隔线
        menu.addItem(NSMenuItem.separator())

        // --- 应用操作区域 ---

        // 首选项（占位，后续 feature/settings-ui 实现）
        let prefsItem = NSMenuItem(
            title: "首选项...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // 退出应用（红色）
        let quitItem = NSMenuItem(
            title: "退出 QuickLUT",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        // 红色菜单项
        let quitTitle = NSAttributedString(
            string: "退出 QuickLUT",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        quitItem.attributedTitle = quitTitle
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openPreferences() {
        // 后续 feature/settings-ui 实现
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
