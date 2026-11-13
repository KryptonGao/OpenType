import Foundation

/// Global dictation pipeline state machine (see PRD Section 2).
/// `idle → connecting → recording → finalizing → processing → inserting → idle`
/// plus terminal "result" states that keep the overlay visible (`success`, `manualCopy`, `error`).
enum DictationState: Equatable, Sendable {
    case idle
    case connecting
    case recording
    case finalizing
    case processing
    case inserting
    case success(note: String?)
    case manualCopy(reason: String)
    case error(String)

    /// A session is actively running; new sessions are rejected.
    var isBusy: Bool {
        switch self {
        case .connecting, .recording, .finalizing, .processing, .inserting:
            true
        case .idle, .success, .manualCopy, .error:
            false
        }
    }
}
