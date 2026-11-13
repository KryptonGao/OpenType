import AppKit
import ApplicationServices
import AVFoundation
import Observation

enum PermissionStatus: Equatable, Sendable {
    case granted, denied, notDetermined

    var isGranted: Bool { self == .granted }
}

@MainActor
protocol PermissionChecking: AnyObject {
    /// Returns `true` once microphone access is granted (prompting the user if undecided).
    func ensureMicrophone() async -> Bool
}

@MainActor
@Observable
final class PermissionManager: PermissionChecking {
    private(set) var microphone: PermissionStatus = .notDetermined
    private(set) var accessibility: PermissionStatus = .denied
    private(set) var inputMonitoring: PermissionStatus = .denied

    init() { refresh() }

    func refresh() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: microphone = .granted
        case .notDetermined: microphone = .notDetermined
        default: microphone = .denied
        }
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        inputMonitoring = CGPreflightListenEventAccess() ? .granted : .denied
    }

    var allGranted: Bool { microphone.isGranted && accessibility.isGranted && inputMonitoring.isGranted }

    func ensureMicrophone() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        refresh()
        return microphone.isGranted
    }

    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refresh()
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        refresh()
    }

    enum Pane: String {
        case microphone = "Privacy_Microphone"
        case accessibility = "Privacy_Accessibility"
        case inputMonitoring = "Privacy_ListenEvent"
    }

    func openSystemSettings(_ pane: Pane) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Relaunches the app. macOS sometimes only applies a new Accessibility / Input Monitoring grant to a fresh process.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
