import Foundation
import os

/// Lightweight diagnostics. Only phase timings / state names are logged — never transcripts, audio or credentials.
enum Diagnostics {
    private static let logger = Logger(subsystem: "com.opentype.OpenType", category: "pipeline")
    private static let enabledFlag = OSAllocatedUnfairLock(initialState: false)

    static var isEnabled: Bool {
        get { enabledFlag.withLock { $0 } }
        set { enabledFlag.withLock { $0 = newValue } }
    }

    static func log(_ message: String) {
        guard isEnabled else { return }
        logger.info("\(message, privacy: .public)")
    }

    /// Redacts bearer tokens / API keys from arbitrary text before it is shown or logged.
    static func redact(_ text: String, secrets: [String] = []) -> String {
        var result = text
        for secret in secrets where secret.count >= 6 {
            result = result.replacingOccurrences(of: secret, with: "***")
        }
        return result
    }
}
