import AppKit
import CoreGraphics
import Observation
import SwiftUI

/// Captures a user-typed shortcut. Press any key combination, or hold modifiers (e.g. `fn`, ⌃⌥) and release.
@MainActor
@Observable
final class HotkeyRecorderModel {
    private(set) var isRecording = false
    private(set) var liveModifiers: CGEventFlags = []
    var message: String?

    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var peakModifiers: CGEventFlags = []
    @ObservationIgnored private var sawKey = false
    @ObservationIgnored private var firstModifierKeyCode: Int64?
    @ObservationIgnored var onCapture: ((HotkeyConfig) -> Void)?
    @ObservationIgnored var onRecordingChange: ((Bool) -> Void)?

    func start() {
        guard !isRecording else { return }
        isRecording = true
        message = nil
        peakModifiers = []
        liveModifiers = []
        sawKey = false
        onRecordingChange?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated { self.handle(event) }
            return handled ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        liveModifiers = []
        onRecordingChange?(false)
    }

    private func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            if event.isARepeat { return true }
            let keyCode = Int64(event.keyCode)
            if keyCode == HotkeyConfig.escapeKeyCode, Self.modifiers(of: event).isEmpty {
                stop() // Esc cancels recording without changing the shortcut
                return true
            }
            sawKey = true
            var mods = Self.modifiers(of: event)
            mods.remove(.maskSecondaryFn) // arrow / F keys set fn on their own
            if NSEvent.ModifierFlags.function.rawValue & event.modifierFlags.rawValue != 0,
               !Self.isFunctionLike(keyCode) {
                mods.insert(.maskSecondaryFn)
            }
            let config = HotkeyConfig(keyCode: keyCode, modifiers: mods)
            switch config.validation {
            case .ok:
                finish(with: config)
            case .invalid(let reason):
                message = reason
            }
            return true

        case .flagsChanged:
            let mods = Self.modifiers(of: event)
            liveModifiers = mods
            if !mods.isEmpty {
                if peakModifiers.isEmpty { firstModifierKeyCode = Int64(event.keyCode) }
                if mods.rawValue.nonzeroBitCount >= peakModifiers.rawValue.nonzeroBitCount { peakModifiers = mods }
            } else {
                // Everything released without a normal key → modifier-only shortcut.
                if !sawKey, !peakModifiers.isEmpty {
                    let single = peakModifiers.rawValue.nonzeroBitCount == 1
                    let side = single ? firstModifierKeyCode.flatMap { HotkeyConfig.modifierKeys[$0] != nil ? $0 : nil } : nil
                    let config = HotkeyConfig(keyCode: nil, modifiers: peakModifiers, modifierKeyCode: side)
                    switch config.validation {
                    case .ok: finish(with: config)
                    case .invalid(let reason): message = reason
                    }
                }
                peakModifiers = []
                firstModifierKeyCode = nil
                sawKey = false
            }
            return true

        default:
            return false
        }
    }

    private func finish(with config: HotkeyConfig) {
        onCapture?(config)
        stop()
    }

    private static func modifiers(of event: NSEvent) -> CGEventFlags {
        let flags = event.modifierFlags
        var result: CGEventFlags = []
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.function) { result.insert(.maskSecondaryFn) }
        return result
    }

    /// Arrow, navigation and F-keys carry the fn flag themselves.
    private static func isFunctionLike(_ keyCode: Int64) -> Bool {
        [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
         123, 124, 125, 126, 115, 116, 117, 119, 121, 114].contains(keyCode)
    }
}

struct HotkeyRecorderRow: View {
    let title: String
    @Binding var hotkey: HotkeyConfig?
    let defaultHotkey: HotkeyConfig
    /// Shows a "清除" button (the shortcut may be unset).
    var allowsClear = false
    /// Returns a message when the captured shortcut collides with another one.
    var conflict: (HotkeyConfig) -> String? = { _ in nil }
    let coordinator: DictationSessionCoordinator
    @State private var model = HotkeyRecorderModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Button(action: { model.isRecording ? model.stop() : model.start() }) {
                    Text(buttonTitle)
                        .frame(minWidth: 150)
                        .foregroundStyle(model.isRecording ? Color.accentColor : Color.primary)
                }
                Button("恢复默认") {
                    hotkey = defaultHotkey
                    model.message = nil
                }
                .disabled(hotkey == defaultHotkey)
                if allowsClear {
                    Button("清除") {
                        hotkey = nil
                        model.message = nil
                    }
                    .disabled(hotkey == nil)
                }
            }
            if let message = model.message {
                Text(message).font(.caption).foregroundStyle(.red)
            } else if model.isRecording {
                Text("请按下想要的按键或组合键（单个按键也可以）；只按一个修饰键（如右 ⌥、fn）后松开也可以。按 Esc 取消。")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let caution = hotkey?.caution {
                Text(caution).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            model.onCapture = { config in
                if let message = conflict(config) {
                    model.message = message
                } else {
                    hotkey = config
                }
            }
            model.onRecordingChange = { coordinator.isRecordingHotkey = $0 }
        }
        .onDisappear { model.stop() }
    }

    private var buttonTitle: String {
        if model.isRecording {
            return model.liveModifiers.isEmpty ? "请按下快捷键…" : HotkeyConfig.describe(modifiers: model.liveModifiers) + " …"
        }
        return hotkey?.displayName ?? "未设置"
    }
}
