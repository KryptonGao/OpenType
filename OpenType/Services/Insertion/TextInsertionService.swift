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
    /// Bundle identifier of the app, used to pick that app's preset. `nil` when unknown.
    var bundleIdentifier: String? = nil
    /// Text the user had selected in the focused control when the session started (Voice Rewrite).
    /// `nil` when nothing (or nothing readable) was selected; never set for secure fields.
    var selectedText: String? = nil
    /// `false` when `selectedText` came from a simulated ⌘C because the app does not expose its selection: it cannot be
    /// compared with the live selection before writing back.
    var selectionIsVerifiable = true
    /// Where the selection (or the caret) is, in Cocoa screen coordinates. Only filled for Writing Tools.
    var anchorRect: CGRect? = nil
}

@MainActor
protocol TextInserting: AnyObject {
    func captureTarget() -> InsertionTarget?
    func insert(_ text: String, into target: InsertionTarget?) async -> InsertionOutcome
    /// Starts preparing apps so their selected text can be read (Voice Rewrite). `isEnabled` is asked each time.
    func startPreparingApps(isEnabled: @escaping () -> Bool)
    /// Like `captureTarget`, plus the selection's position and, for apps that hide their selection from
    /// accessibility, a simulated ⌘C fallback (Writing Tools).
    func captureForWritingTools() async -> InsertionTarget?
    /// Sends ⌘Z to the app the text was written to. `false` when that app is no longer in front.
    func sendUndo(to target: InsertionTarget) -> Bool
}

extension TextInserting {
    func startPreparingApps(isEnabled: @escaping () -> Bool) {}
    func captureForWritingTools() async -> InsertionTarget? { captureTarget() }
    func sendUndo(to target: InsertionTarget) -> Bool { false }
}

/// Handles 3-tier insertion: Accessibility direct write → simulated paste → manual copy.
@MainActor
final class TextInsertionService: TextInserting {
    private static let secureSubrole = "AXSecureTextField"
    /// Chromium / Electron apps (Claude, VS Code, Slack, Chrome, …) only build their accessibility tree, and so only
    /// expose the focused field and its selection, once an assistive technology asks for it with this attribute.
    private static let manualAccessibility = "AXManualAccessibility"

    private var preparedPIDs: Set<pid_t> = []
    /// Registered once and kept for the lifetime of the app (the service is app-wide).
    private var observers: [NSObjectProtocol] = []
    private var isPreparingEnabled: () -> Bool = { false }

    func startPreparingApps(isEnabled: @escaping () -> Bool) {
        isPreparingEnabled = isEnabled
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.prepare(app) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { _ = self?.preparedPIDs.remove(app.processIdentifier) }
        })
        if let front = NSWorkspace.shared.frontmostApplication { prepare(front) }
    }

    /// Asks an app to expose its accessibility tree. Done as soon as the app becomes active, so the tree is ready
    /// long before the user selects text and presses the shortcut. Apps without the attribute just ignore it.
    private func prepare(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid != ProcessInfo.processInfo.processIdentifier, !preparedPIDs.contains(pid),
              isPreparingEnabled(), isAccessibilityTrusted() else { return }
        preparedPIDs.insert(pid)
        let result = AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), Self.manualAccessibility as CFString, kCFBooleanTrue)
        Diagnostics.log("prepare accessibility app=\(app.bundleIdentifier ?? "?") result=\(result.rawValue)")
    }

    func isAccessibilityTrusted(promptIfNeeded: Bool = false) -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": promptIfNeeded] as CFDictionary)
    }

    // MARK: Target capture

    func captureTarget() -> InsertionTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        if isPreparingEnabled() { prepare(app) } // no-op when already done
        let element = isAccessibilityTrusted() ? focusedElement(ofPID: app.processIdentifier) : nil
        let isSecure = element.map(Self.isSecureField) ?? false
        if Diagnostics.isEnabled { Self.logCapture(app: app, element: element) }
        return InsertionTarget(
            pid: app.processIdentifier,
            appName: app.localizedName ?? String(localized: "未知应用"),
            element: element,
            isSecure: isSecure,
            bundleIdentifier: app.bundleIdentifier,
            selectedText: isSecure ? nil : element.flatMap(Self.selectedText(of:))
        )
    }

    // MARK: Writing Tools capture

    func captureForWritingTools() async -> InsertionTarget? {
        guard var target = captureTarget() else { return nil }
        guard !target.isSecure else { return target }
        if let element = target.element { target.anchorRect = Self.anchorRect(of: element) }
        // Only when the app does not say what is selected at all: an app that reports an empty selection (even
        // one like VS Code that copies the whole line on an empty ⌘C) must not get a ⌘C.
        if target.selectedText == nil, Self.selectionIsUnknown(target.element),
           let copied = await selectionViaCopy(pid: target.pid) {
            target.selectedText = copied
            target.selectionIsVerifiable = false
        }
        return target
    }

    func sendUndo(to target: InsertionTarget) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid,
              let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_Z), keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_Z), keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }

    private static func selectionIsUnknown(_ element: AXUIElement?) -> Bool {
        guard let element else { return true }
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) != .success
    }

    /// Copies the selection with a simulated ⌘C and puts the clipboard back afterwards.
    private func selectionViaCopy(pid: pid_t) async -> String? {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return nil }
        let pasteboard = NSPasteboard.general
        let backup = Self.snapshot(of: pasteboard)
        let before = pasteboard.changeCount
        await waitForModifierRelease()
        guard Self.postCommandKey(kVK_ANSI_C) else { return nil }
        for _ in 0..<15 { // up to ~300 ms for the app to answer
            if pasteboard.changeCount != before { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard pasteboard.changeCount != before else { return nil } // nothing was copied: nothing selected
        let copied = pasteboard.string(forType: .string)
        Self.restore(backup, to: pasteboard, expectedChangeCount: pasteboard.changeCount)
        guard let copied, !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              copied.count <= Self.maxSelectionLength else { return nil }
        return copied
    }

    /// Screen rectangle of the selection (or the caret), else of the focused control; Cocoa coordinates.
    private static func anchorRect(of element: AXUIElement) -> CGRect? {
        var rect: CGRect?
        var rangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            var range = CFRange()
            if AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) { // type verified above
                rect = bounds(of: range, in: element)
                if (rect == nil || rect == .zero), range.length == 0 {
                    // A caret has no extent in many apps: use the character next to it.
                    let next = CFRange(location: range.location, length: 1)
                    let previous = CFRange(location: max(range.location - 1, 0), length: 1)
                    rect = bounds(of: next, in: element) ?? bounds(of: previous, in: element)
                }
            }
        }
        if rect == nil || rect == .zero { rect = frame(of: element) }
        guard let rect, rect != .zero, rect.width.isFinite, rect.height.isFinite,
              let primary = NSScreen.screens.first else { return nil }
        // Accessibility uses a top-left origin on the primary screen; Cocoa a bottom-left one.
        return CGRect(x: rect.minX, y: primary.frame.height - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func bounds(of range: CFRange, in element: AXUIElement) -> CGRect? {
        var range = range
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &value
        ) == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil // type verified above
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
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
        // Voice Rewrite replaces the selection: if it changed while we were listening, the result no longer
        // belongs there. Never overwrite something else.
        if let original = target.selectedText, target.selectionIsVerifiable {
            guard let current, Self.selectedText(of: current) == original else {
                return .focusLost(reason: String(localized: "所选文字在录音期间已改变"))
            }
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
        let backup = Self.snapshot(of: pasteboard)

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

    private static func snapshot(of pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
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

    private static func postCommandV() -> Bool { postCommandKey(kVK_ANSI_V) }

    private static func postCommandKey(_ key: Int) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: false)
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

    /// Why a selection was (not) readable: never logs the text itself.
    private static func logCapture(app: NSRunningApplication, element: AXUIElement?) {
        guard let element else {
            Diagnostics.log("capture app=\(app.bundleIdentifier ?? "?") focusedElement=none")
            return
        }
        var role: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        let length = (value as? String)?.count ?? -1
        Diagnostics.log("capture app=\(app.bundleIdentifier ?? "?") role=\((role as? String) ?? "?") selectedTextError=\(error.rawValue) selectedLength=\(length)")
    }

    /// Longest selection that is sent to the model; longer selections are treated as "no selection".
    static let maxSelectionLength = 20_000

    /// The currently selected text of a control, or `nil` when empty / whitespace-only / unreadable / too long.
    static func selectedText(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= maxSelectionLength else { return nil }
        return text
    }

    private static func stringValue(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
