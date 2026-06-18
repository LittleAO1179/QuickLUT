import SwiftUI
import AppKit

/// 可点击编辑的数值字段：平时显示格式化文本，点击进入编辑，点外部自动提交
struct EditableValueField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: String = "%.2f"
    var isPercent: Bool = false

    @State private var isEditing = false
    @State private var text = ""
    @State private var monitor: Any? = nil
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .onSubmit(commit)
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { commit() }
                    }
                    .onAppear { focused = true }
            } else {
                Text(displayText)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: beginEdit)
            }
        }
        .font(.caption.monospacedDigit())
        .frame(width: LayoutMetrics.valueWidth, alignment: .trailing)
        .onDisappear { removeMonitor() }
    }

    private var displayText: String {
        isPercent ? "\(Int(value.rounded()))%" : String(format: format, value)
    }

    private func beginEdit() {
        text = isPercent ? String(Int(value.rounded())) : String(format: format, value)
        isEditing = true
        removeMonitor()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            DispatchQueue.main.async {
                guard self.isEditing,
                      let window = event.window,
                      let fieldEditor = window.firstResponder as? NSTextView else { return }
                // 将点击点从 window 坐标转为 fieldEditor 坐标，检查是否点在编辑框内
                let clickInField = fieldEditor.convert(event.locationInWindow, from: nil)
                if !fieldEditor.bounds.contains(clickInField) {
                    self.commit()
                }
            }
            return event
        }
    }

    private func commit() {
        if let parsed = Double(text.trimmingCharacters(in: .whitespaces)) {
            value = min(max(parsed, range.lowerBound), range.upperBound)
        }
        isEditing = false
        removeMonitor()
    }

    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
