import ApplicationServices
import CoreGraphics
import Foundation

/// Global hotkey monitor based on a CoreGraphics event tap.
/// Needs Accessibility / Input Monitoring permission. Does not work while Secure Event Input is on.
@MainActor
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onCancel: (() -> Void)?
    /// Return `false` (e.g. hotkeys paused) to let events pass through untouched.
    var isEnabled: () -> Bool = { true }
    /// Return `true` while a session / result is visible so `Escape` is consumed and cancels it.
    var shouldInterceptEscape: () -> Bool = { false }

    var hotkey: HotkeyConfig = .default

    private(set) var isListening = false
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false
    private var swallowKeyUp = false

    private var suppressedUntilModifiersChange = false
    /// Modifier-only shortcuts (fn, right ⌥, ⌃⌥ …) fire as a "tap" when the modifier is released,
    /// and only if no other key / mouse button went down while it was held. That keeps ordinary chords
    /// such as ⌘C or ⌥-click from triggering dictation, while a quick tap works instantly.
    private var pendingTap = false
    private static let escapeKeyCode = HotkeyConfig.escapeKeyCode

    /// Modifiers that take part in matching. `fn` is only compared when the shortcut itself uses it,
    /// because arrow / function keys set the fn flag on their own.
    private var relevantModifiers: CGEventFlags {
        var mask = HotkeyConfig.classicModifiers
        if hotkey.modifiers.contains(.maskSecondaryFn) { mask.insert(.maskSecondaryFn) }
        return mask
    }

    /// Returns `false` when the tap could not be created (missing permission). Safe to call repeatedly.
    @discardableResult
    func startListening() -> Bool {
        if isListening { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyEventTapCallback,
            userInfo: refcon
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        isListening = true
        return true
    }

    func stopListening() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        isListening = false
        pendingTap = false
        releaseIfHeld()
    }

    // MARK: Event handling

    /// Returns `true` when the event must be swallowed.
    func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags, isAutoRepeat: Bool) -> Bool {
        let modifiers = flags.intersection(relevantModifiers)
        let required = hotkey.modifiers
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            pendingTap = false
            releaseIfHeld() // we may have missed the key-up: never leave a session stuck
            return false

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            abortPendingTap() // e.g. ⌥-click: the modifier is part of another gesture
            return false

        case .keyDown:
            if let hotkeyCode = hotkey.keyCode, keyCode == hotkeyCode, modifiers == required {
                if isAutoRepeat { return isHeld }
                guard !isHeld, isEnabled() else { return false }
                isHeld = true
                swallowKeyUp = true
                onPress?()
                return true
            }
            if keyCode == Self.escapeKeyCode, shouldInterceptEscape() {
                isHeld = false
                pendingTap = false
                suppressedUntilModifiersChange = true
                onCancel?()
                return true
            }
            // Modifier-only shortcut used as part of another chord (e.g. ⌃⌥ + key): abort, don't interfere.
            if hotkey.keyCode == nil { abortPendingTap() }
            return false

        case .keyUp:
            if keyCode == hotkey.keyCode {
                releaseIfHeld()
                if swallowKeyUp {
                    swallowKeyUp = false
                    return true
                }
            }
            return false

        case .flagsChanged:
            if hotkey.keyCode != nil {
                if isHeld, !modifiers.isSuperset(of: required) { releaseIfHeld() } // required modifier released early
                return false
            }
            if let side = hotkey.modifierKeyCode, let info = HotkeyConfig.modifierKeys[side] {
                // Single physical modifier key (e.g. right ⌥): react only to that key's own transitions.
                let down = side == 63 ? flags.contains(.maskSecondaryFn) : flags.rawValue & info.deviceBit != 0
                if keyCode == side {
                    if down {
                        if modifiers.subtracting(required).isEmpty { beginModifierOnlyPress() }
                    } else {
                        endModifierOnlyPress()
                        suppressedUntilModifiersChange = false
                    }
                } else if !down {
                    endModifierOnlyPress()
                } else {
                    abortPendingTap() // another modifier joined: not a plain tap
                }
                return false
            }
            if !modifiers.isSuperset(of: required) {
                endModifierOnlyPress()
                suppressedUntilModifiersChange = false
            } else if modifiers == required {
                beginModifierOnlyPress()
            } else {
                abortPendingTap() // an extra modifier joined: not a plain tap
            }
            return false

        default:
            return false
        }
    }

    private func beginModifierOnlyPress() {
        guard !pendingTap, !suppressedUntilModifiersChange, isEnabled() else { return }
        pendingTap = true
    }

    /// The modifier went up: if nothing interrupted the press, it counts as one tap of the shortcut.
    private func endModifierOnlyPress() {
        guard pendingTap else { return }
        pendingTap = false
        guard isEnabled() else { return }
        onPress?()
        onRelease?()
    }

    private func abortPendingTap() {
        guard pendingTap else { return }
        pendingTap = false
        suppressedUntilModifiersChange = true
    }

    private func releaseIfHeld() {
        guard isHeld else { return }
        isHeld = false
        onRelease?()
    }
}

private func hotkeyEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    let address = Int(bitPattern: refcon)
    // The tap source is installed on the main run loop, so this callback already runs on the main thread.
    let swallow = MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return false }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(pointer).takeUnretainedValue()
        return manager.handle(type: type, keyCode: keyCode, flags: flags, isAutoRepeat: isAutoRepeat)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
