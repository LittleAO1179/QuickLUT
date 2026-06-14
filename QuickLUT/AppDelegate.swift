import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 检查 ffmpeg
        if !FFmpegLocator.isAvailable() {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "未找到 ffmpeg"
                alert.informativeText = "QuickLUT 需要 ffmpeg 才能处理视频。请在终端运行：\nbrew install ffmpeg"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        }

        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "paintpalette.fill",
                accessibilityDescription: "QuickLUT"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

        // 创建 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView()
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 确保 popover 获得焦点
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
