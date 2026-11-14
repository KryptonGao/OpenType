import ApplicationServices
import AppKit
import Carbon.HIToolbox
import Foundation

enum InsertionOutcome: Equatable, Sendable {
    case insertedViaAccessibility
    case insertedViaPasteboard
    case requiresManualCopy(reason: String)
    /// The user moved focus away from the original input (other app or other control): the text must not be
    /// written anywhere else, so the caller puts it on the clipboard and notifies the user.
    case focusLost(reason: String)
}

/// Snapshot of where the user was typing when dictation started.
struct InsertionTarget {
    let pid: pid_t
    let appName: String
    let element: AXUIElement?
    let isSecure: Bool
}

@MainActor
protocol TextInserting: AnyObject {
    func captureTarget() -> InsertionTarget?
    func insert(_ text: String, into target: InsertionTarget?) async -> InsertionOutcome
}

/// Handles 3-tier insertion: Accessibility direct write → simulated paste → manual copy.
@MainActor
final class TextInsertionService: TextInserting {
    private static let secureSubrole = "AXSecureTextField"

    func isAccessibilityTrusted(promptIfNeeded: Bool = false) -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": promptIfNeeded] as CFDictionary)
    }

    // MARK: Target capture

    func captureTarget() -> InsertionTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let element = isAccessibilityTrusted() ? focusedElement(ofPID: app.processIdentifier) : nil
        return InsertionTarget(
            pid: app.processIdentifier,
            appName: app.localizedName ?? String(localized: "未知应用"),
            element: element,
            isSecure: element.map(Self.isSecureField) ?? false
        )
    }

    // MARK: Insertion

    func insert(_ text: String, into target: InsertionTarget?) async -> InsertionOutcome {
        guard !text.isEmpty else { return .requiresManualCopy(reason: String(localized: "文本为空")) }
        guard let target else { return .requiresManualCopy(reason: String(localized: "未能确定目标输入框")) }
        guard !target.isSecure else {
            return .requiresManualCopy(reason: String(localized: "目标是密码/安全输入框，已禁止自动写入"))
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid else {
            return .focusLost(reason: String(localized: "录音期间已切换应用，无法写回「\(target.appName)」"))
        }
        guard isAccessibilityTrusted() else {
            return .requiresManualCopy(reason: String(localized: "未授予辅助功能权限，无法自动插入"))
        }
        guard !IsSecureEventInputEnabled() else {
            return .requiresManualCopy(reason: String(localized: "系统处于安全输入模式（可能有密码框处于焦点）"))
        }

        // Re-validate the focused control: it must still be the one captured at the start.
        let current = focusedElement(ofPID: target.pid)
        if let original = target.element {
            guard let current, CFEqual(original, current) else {
                return .focusLost(reason: String(localized: "输入焦点已离开原输入框"))
            }
        }
        if let current, Self.isSecureField(current) {
            return .requiresManualCopy(reason: String(localized: "目标是密码/安全输入框，已禁止自动写入"))
        }

        if let element = target.element ?? current, await insertViaAccessibility(text, element: element) {
            return .insertedViaAccessibility
        }
        if await insertViaPasteboard(text) {
            return .insertedViaPasteboard
        }
        return .requiresManualCopy(reason: String(localized: "目标控件不支持自动插入"))
    }

    // MARK: Tier 1 — Accessibility

    private func insertViaAccessibility(_ text: String, element: AXUIElement) async -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue,
              let before = Self.stringValue(of: element) else { return false } // unverifiable → try paste instead
        guard AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
        else { return false }
        try? await Task.sleep(for: .milliseconds(60))
        // Many apps report success without changing anything: only trust a verified change.
        guard let after = Self.stringValue(of: element) else { return false }
        return after != before
    }

    // MARK: Tier 2 — Pasteboard

    private func insertViaPasteboard(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let backup: [[(NSPasteboard.PasteboardType, Data)]] = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Ask clipboard managers not to record this transient value.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let ownChangeCount = pasteboard.changeCount

        await waitForModifierRelease()
        guard Self.postCommandV() else {
            Self.restore(backup, to: pasteboard, expectedChangeCount: ownChangeCount)
            return false
        }
        try? await Task.sleep(for: .milliseconds(600)) // let the target read the pasteboard
        Self.restore(backup, to: pasteboard, expectedChangeCount: ownChangeCount)
        return true
    }

    /// Restores the previous clipboard only if nobody (e.g. the user) modified it in the meantime.
    private static func restore(
        _ backup: [[(NSPasteboard.PasteboardType, Data)]],
        to pasteboard: NSPasteboard,
        expectedChangeCount: Int
    ) {
        guard pasteboard.changeCount == expectedChangeCount else { return }
        pasteboard.clearContents()
        let items = backup.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }

    private func waitForModifierRelease() async {
        let modifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        for _ in 0..<25 {
            let state = CGEventSource.flagsState(.combinedSessionState)
            if state.intersection(modifiers).isEmpty { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func postCommandV() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }

    // MARK: AX helpers

    private func focusedElement(ofPID pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement) // type verified above
    }

    private static func isSecureField(_ element: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           (subrole as? String) == secureSubrole { return true }
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           (role as? String) == secureSubrole { return true }
        return false
    }

    private static func stringValue(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
