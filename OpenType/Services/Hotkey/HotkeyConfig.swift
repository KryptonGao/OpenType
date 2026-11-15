import CoreGraphics
import Foundation

/// A user-defined tap-to-toggle dictation shortcut.
/// - `keyCode != nil`: a normal chord (modifiers + key), e.g. ⌃⌥Space or F5.
/// - `keyCode == nil`: modifier-only, e.g. hold `fn`, a single (left/right) ⌥ or ⌃⌥ together.
/// Any single key is allowed (Esc is reserved for cancelling).
struct HotkeyConfig: Codable, Equatable, Sendable {
    var keyCode: Int64?
    private var modifierBits: UInt64
    /// For a single-modifier shortcut: the physical key (left/right side), e.g. 61 = right ⌥.
    var modifierKeyCode: Int64?

    var modifiers: CGEventFlags {
        get { CGEventFlags(rawValue: modifierBits) }
        set { modifierBits = newValue.rawValue }
    }

    init(keyCode: Int64?, modifiers: CGEventFlags, modifierKeyCode: Int64? = nil) {
        self.keyCode = keyCode
        self.modifierBits = modifiers.intersection(Self.allModifiers).rawValue
        self.modifierKeyCode = keyCode == nil ? modifierKeyCode : nil
    }

    /// Physical modifier keys: flag, device-dependent "this side is down" bit, display name.
    static let modifierKeys: [Int64: (flag: CGEventFlags, deviceBit: UInt64, name: String)] = [
        54: (.maskCommand, 0x10, String(localized: "右 ⌘")), 55: (.maskCommand, 0x08, String(localized: "左 ⌘")),
        56: (.maskShift, 0x02, String(localized: "左 ⇧")), 60: (.maskShift, 0x04, String(localized: "右 ⇧")),
        58: (.maskAlternate, 0x20, String(localized: "左 ⌥")), 61: (.maskAlternate, 0x40, String(localized: "右 ⌥")),
        59: (.maskControl, 0x01, String(localized: "左 ⌃")), 62: (.maskControl, 0x2000, String(localized: "右 ⌃")),
        63: (.maskSecondaryFn, 0, "fn")
    ]

    static let `default` = HotkeyConfig(keyCode: 49, modifiers: [.maskControl, .maskAlternate])

    /// ⌃⌥T — default shortcut for voice translation.
    static let defaultTranslation = HotkeyConfig(keyCode: 17, modifiers: [.maskControl, .maskAlternate])

    /// ⌃⌥W — default shortcut for the Writing Tools panel.
    static let defaultWritingTools = HotkeyConfig(keyCode: 13, modifiers: [.maskControl, .maskAlternate])

    static let escapeKeyCode: Int64 = 53
    static let classicModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    static let allModifiers: CGEventFlags = classicModifiers.union(.maskSecondaryFn)

    private static let functionKeys: Set<Int64> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]

    enum Validation: Equatable {
        case ok
        case invalid(String)
    }

    var validation: Validation {
        if let keyCode {
            return keyCode == Self.escapeKeyCode ? .invalid(String(localized: "Esc 已保留为取消键")) : .ok
        }
        return modifiers.isEmpty ? .invalid(String(localized: "请按下至少一个按键")) : .ok
    }

    /// Non-blocking warning shown under the recorder.
    var caution: String? {
        if let keyCode {
            let hasModifier = !modifiers.intersection(Self.classicModifiers).isEmpty
            if !hasModifier, !Self.functionKeys.contains(keyCode) {
                return String(localized: "该按键会被快捷键独占，无法再正常输入这个字符；建议搭配修饰键。")
            }
            return nil
        }
        return String(localized: "仅修饰键的快捷键在松开时触发（轻点即可），按住期间若按了其它键或鼠标则不触发（避免和 ⌘C 等组合键冲突）。")
    }

    var displayName: String {
        var text = ""
        if modifiers.contains(.maskSecondaryFn) { text += "fn " }
        if modifiers.contains(.maskControl) { text += "⌃" }
        if modifiers.contains(.maskAlternate) { text += "⌥" }
        if modifiers.contains(.maskShift) { text += "⇧" }
        if modifiers.contains(.maskCommand) { text += "⌘" }
        guard let keyCode else {
            if let modifierKeyCode, let name = Self.modifierKeys[modifierKeyCode]?.name {
                return modifierKeyCode == 63 ? String(localized: "fn（仅修饰键）") : String(localized: "\(name) 键（单独按下）")
            }
            return text.trimmingCharacters(in: .whitespaces) + String(localized: "（仅修饰键）")
        }
        let key = Self.keyNames[keyCode] ?? String(localized: "键码 \(keyCode)")
        return text.isEmpty ? key : text + (text.hasSuffix(" ") ? "" : " ") + key
    }

    static func describe(modifiers: CGEventFlags) -> String {
        HotkeyConfig(keyCode: 0, modifiers: modifiers).displayName.replacingOccurrences(of: " A", with: "")
    }

    private static let keyNames: [Int64: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
        13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I",
        35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc", 76: "Enter",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16",
        107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]
}
