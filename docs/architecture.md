# Architecture

OpenType is a Swift 6 / SwiftUI / AppKit app for macOS 26. It is a menu-bar app (`LSUIElement`) with a native main window, a non-activating overlay panel and a global event tap. There is no backend: every network call goes straight from the app to a provider the user configured.

## Design principles

1. **Low latency.** Audio capture starts immediately; chunks queue while the speech service is still connecting.
2. **Never steal focus.** The overlay is a non-activating `NSPanel`, so the target app keeps keyboard focus.
3. **ASR and LLM are decoupled.** Either side can be swapped without touching the other.
4. **Privacy first.** No audio on disk, no telemetry, logs without content.
5. **Never lose the user's words.** Every failure path keeps whatever text was already recognized.

## Source layout

```
OpenType/
├── App/              OpenTypeApp (scenes, AppContainer), AppDelegate
├── Core/
│   ├── DictationSessionCoordinator.swift   pipeline orchestration
│   ├── DictationState.swift                state machine enum
│   ├── TranscriptAggregator.swift          merges ASR events in utterance order
│   ├── UsageStats.swift                    Home statistics
│   └── Dictionary/                         DictionaryModels, DictionaryMatcher
├── Services/
│   ├── Audio/        AudioCaptureService: AVAudioEngine capture, resample, chunking
│   ├── ASR/          ASRService protocol, Bailian realtime, Qwen-Audio, DeepSeek
│   ├── LLM/          LLMProvider, LLMClient (HTTP adapters), prompts (TextProcessor)
│   ├── Hotkey/       HotkeyConfig, HotkeyManager (CGEventTap)
│   ├── Insertion/    TextInsertionService (three-tier insertion)
│   ├── Permissions/  PermissionManager
│   ├── Notifications/UserNotifier
│   └── Update/       AppUpdater, UpdateInstaller, UpdateModels
├── Storage/          SettingsStore, CredentialStore, HistoryStore, DictionaryStore, AppLanguage
├── UI/
│   ├── Main/         MainWindowView, HomeView, HistoryView, DictionaryView
│   ├── Settings/     SettingsView, HotkeyRecorder, SecretField
│   ├── MenuBar/      MenuBarView
│   └── Overlay/      OverlayPanelController, OverlayView
├── Resources/        Assets, Localizable.xcstrings, InfoPlist.xcstrings, Dictionary/dict-*.json
└── Util/             Diagnostics
OpenTypeTests/        Swift Testing unit tests
```

## Object graph

`AppContainer` in `App/OpenTypeApp.swift` is the single shared object graph. It exists because the global hotkey must be live before any menu is opened.

```
AppContainer
├── overlay: OverlayPanelController
├── historyStore: HistoryStore
├── dictionaryStore: DictionaryStore
├── coordinator: DictationSessionCoordinator
│     owns SettingsStore, CredentialStore, two HotkeyManagers, PermissionManager,
│     AudioCapturing, TextProcessor, TextInserting, UserNotifying
├── router: MainWindowRouter        selects the main window tab
└── updater: AppUpdater
```

`AppDelegate.applicationDidFinishLaunching` calls `coordinator.start()` (wires the shortcuts) and `updater.startAutomaticChecks()`. On termination it cancels any session and stops the event taps.

State holders (`DictationSessionCoordinator`, `SettingsStore`, `HistoryStore`, `DictionaryStore`, `PermissionManager`, `AppUpdater`) are `@MainActor @Observable` classes, and SwiftUI observes them directly.

## The session pipeline

### State machine

```
idle → connecting → recording → finalizing → processing → inserting → idle
```

Plus result states that keep the overlay visible: `success(note)`, `manualCopy(reason)` and `error(message)`. `DictationState.isBusy` is true for the five working states; a new session cannot start while busy.

### Session kinds

All kinds share one pipeline and differ only in the final model call. They are expressed as flags on the coordinator rather than separate types:

| Kind | `translationTarget` | `isHelpMeSay` | Model step |
| --- | --- | --- | --- |
| Dictation | nil | false | `TextProcessor` cleanup (skipped when Raw or AI is off) |
| Translation | set | false | Translation prompt, always uses the LLM profile |
| Say It for Me | nil | true | Say It for Me prompt, profile or DeepSeek web search |
| Translate & Say It for Me | set | true | Say It for Me prompt plus a translation addendum |

`SessionMode` is `.toggle` (start, then stop explicitly) or `.hold` (releasing the key ends the recording).

### Step by step

`runPipeline(_:)` in `DictationSessionCoordinator.swift`:

1. **Preconditions.** Build the `ASRConfig` from settings and credentials, then ensure Microphone permission.
2. **Capture.** `AudioCapturing.start` returns an `AsyncStream<Data>` of 100 ms PCM16 chunks. Capture starts before the ASR connection is ready; chunks wait in a bounded queue.
3. **Connect.** `makeASR(config)` creates a single-use `ASRService`. A task consumes `asr.events` and feeds the aggregator. `connect()` resolves when the server confirms the session; the state moves `connecting → recording`.
4. **Stream.** Each chunk goes to `asr.sendAudio`. The stream ends when `stopRecording()` calls `audio.stop()`, which flushes the last partial chunk.
5. **Too little audio?** Under two chunks (about 0.2 s) is treated as an accidental tap and ends quietly.
6. **Finalize** (`finalizing`). Send `commit()` when turn detection is manual, then `finish()`. A watchdog closes the socket after `asr.finalizeTimeout` (10 s by default, 90 s for DeepSeek). On timeout the best-effort text is used and a note is added. Empty text means no valid speech, so nothing is inserted.
7. **Dictionary** (see [Dictionary](dictionary.md)). `dictionaryStore.correct` fixes known terms deterministically; `dictionaryStore.addendum` builds the hint section for the prompt.
8. **Process** (`processing`). One of the four model steps above, with its own failure policy (see [Error handling](#error-handling-and-recovery)).
9. **Insert** (`inserting`). Build a `SessionRecord`, then `TextInserting.insert`. The outcome decides `success`, `manualCopy` or the focus-lost path.

### Concurrency rules

- **Session IDs.** Every session gets a `UUID`. Each `await` continuation checks `isCurrent(id)` before touching state, so late callbacks from a cancelled or finished session are ignored.
- **One at a time.** `beginSession` returns immediately if `state.isBusy`.
- **Cancellation.** `cancelSession()` tears down audio and the ASR, cancels the pipeline task, resets all per-session state, hides the overlay, and returns to `idle`. It is what `Esc`, finishing silently and cleanup all use.
- **Overlay lifetime.** `overlayToken` gates the delayed auto-dismiss, so an old dismissal cannot hide a newer session's overlay.
- **Audio thread.** The audio callback only converts and enqueues. It never touches the network.

### Hold-to-talk upgrade

A hotkey press always starts an ordinary dictation session (`holdCandidateID` remembers it). If the key is still down after `longPressDelay` (450 ms), `HotkeyManager` fires `onLongPress`, and the coordinator upgrades the running session in place to Say It for Me (`isHelpMeSay = true`, `sessionMode = .hold`). Releasing the key calls `handleHotkeyRelease`, which stops the recording. Modifier-only shortcuts only report a press on release, so there the long press itself starts the session.

## Components

### Audio capture

`AudioCaptureService` runs an `AVAudioEngine` input tap, converts with `AVAudioConverter` to PCM16, 16 kHz, mono, and slices into 3200-byte (100 ms) chunks. The chunk stream has a bounded buffer of 600 chunks (about 60 s). Overflow is reported as an interruption instead of silently dropping audio. It also reports an RMS level mapped over a 50 dB window for the overlay waveform, and surfaces device configuration changes as interruptions. Interruptions end the recording and the session continues with what was captured.

### Speech recognition

`ASRService` is a single-use streaming interface: `connect`, `sendAudio`, `commit`, `finish`, `close`, an `events` stream, a `finalizeTimeout`, and `probe()` for the Settings connection test. Three implementations exist; see [Services Reference](services-reference.md#speech-recognition).

`TranscriptAggregator` merges events by item ID:

- `preview` replaces the previous snapshot of an item (it is not appended).
- `completed` replaces the temporary content with the final transcript.
- `solidText` (completed + confirmed text) and `stashText` (the unstable tail of the newest item) drive the overlay.
- `finalText` contains only completed items; `bestEffortText` also includes unfinished text and is the fallback.
- Joining utterances inserts a space only between two Latin word characters, so CJK text is not spaced.

### LLM

`LLMProvider` has three entry points: `process`, `processWithUsage` and `processWithWebSearch`. `HTTPLLMProvider` implements them for three wire protocols. Request building and response parsing are pure functions (`LLMRequestBuilder`, `LLMResponseParser`) so they are unit-tested without a network. `TextProcessor` holds every prompt. See [Services Reference](services-reference.md#llm-providers).

### Hotkeys

`HotkeyManager` installs a `CGEventTap` (session tap, head insert, default options) for key down/up, flags changed and mouse down events. The callback runs on the main run loop. For each event it decides whether to swallow it:

- A chord shortcut matches key code plus exact modifiers, swallows the key-down and the matching key-up, and ignores auto-repeat.
- A modifier-only shortcut arms on the modifier going down and fires on release, but is aborted if any other key or mouse button is pressed meanwhile.
- `Esc` is swallowed and cancels only while a session is visible (`shouldInterceptEscape`).
- If the system disables the tap (timeout or user input), the manager re-enables it and releases any held state so a session never gets stuck.

`startListening()` fails without permission, so the coordinator retries every 1.5 s. Two managers exist, one for dictation and one for translation. `HotkeyConfig` models either kind of shortcut and validates it (`Esc` is reserved).

### Text insertion

`TextInsertionService` captures an `InsertionTarget` (app PID, name, the focused `AXUIElement`, whether it is secure) when the session starts, and revalidates it before writing. The three tiers and the safety checks are described in the [User Guide](user-guide.md#text-insertion). The result is an `InsertionOutcome`: `insertedViaAccessibility`, `insertedViaPasteboard`, `requiresManualCopy(reason)` or `focusLost(reason)`.

### Storage

| Store | Backing | Notes |
| --- | --- | --- |
| `SettingsStore` | `UserDefaults` | Every property writes through in `didSet`. Invalid stored values fall back to defaults. |
| `CredentialStore` | `~/.opentype/credentials.json` | Flat `{account: value}` JSON, `0700` / `0600`. `InMemoryCredentialStore` for tests. Migrates legacy Keychain items once. |
| `HistoryStore` | `history.json` in Application Support | Newest first, capped at 5000. Writes are chained so they land in order. |
| `DictionaryStore` | `dictionary.json` in Application Support | Rebuilds the `DictionaryMatcher` on every change. |

Credential accounts are `bailian_api_key`, `deepseek_asr_api_key`, `deepseek_web_search_api_key` and `llm_profile_<UUID>`.

### UI

- `OpenTypeApp` declares a `MenuBarExtra` and one `Window` (`MainWindowView`, 1000 × 700 default). The menu bar icon is an asset-catalog template image chosen from coordinator state.
- `MainWindowRouter` lets the menu bar and the app menu choose the main window tab (`home`, `history`, `dictionary`, `settings(page)`).
- `OverlayPanelController` hosts `OverlayView` in a non-activating panel. It positions itself at the top or bottom center of the screen.
- `HotkeyRecorder` is the shortcut field. While it records, `coordinator.isRecordingHotkey` suppresses the real shortcut.

### Updater

`AppUpdater` is an observable state machine (`idle`, `checking`, `upToDate`, `available`, `downloading`, `readyToInstall`, `failed`). `UpdateInstaller` downloads, verifies and swaps the bundle. See [Releasing](releasing.md#how-the-in-app-updater-works).

### Localization

The UI is localized with a String Catalog (`Localizable.xcstrings`). **Source strings in code are Chinese** (the project's development language), with English, Simplified Chinese, Traditional Chinese, Japanese and Korean translations in the catalog. `AppLanguage` stores the user's choice in the app's `AppleLanguages` default, which macOS reads at launch, so a change needs a restart. When adding a user-visible string, add it to the catalog in all five languages.

## Error handling and recovery

| Failure | Behavior |
| --- | --- |
| Config or key missing | Error in the overlay with a precise message; no audio sent |
| Microphone permission missing | Error with instructions |
| ASR fails or disconnects | Keep the best-effort recognized text in `pendingText` for copying; never guess missing text |
| ASR finalize timeout | Use best-effort text and add a note |
| No valid speech or tap under 0.2 s | End silently; nothing inserted |
| Cleanup LLM fails | Insert the raw text with a note (if fallback is on), else error with recoverable text |
| Translation LLM fails | Never insert untranslated text; error with recoverable raw text |
| Say It for Me fails | Raw-text fallback only when not translating; otherwise error with recoverable text |
| Audio device change or overflow | End the recording and continue with what was captured, with a note |
| Focus lost before insertion | Do not write; copy to clipboard and notify |
| Secure field or Secure Event Input | Do not write; manual copy |

Errors have a `userMessage` (`ASRError`, `LLMError`, `AudioCaptureError`, `UpdateError`). Messages that echo provider output pass through `Diagnostics.redact`.

## Testability

The coordinator takes every collaborator through its initializer (audio, ASR factory, LLM factory, inserter, notifier, overlay, stores, permission checker), with real implementations as defaults. Tests inject fakes to drive full sessions end to end (success, fallback, cancellation, each failure, translation, Say It for Me) without a microphone, network or Accessibility. See [Development](development.md#testing).

## Entitlements and Info.plist

- App Sandbox is **off**. The global event tap and Accessibility insertion are not possible in the sandbox.
- `com.apple.security.device.audio-input` is **on**.
- `LSUIElement` is true: no Dock icon by default. `showDockIcon` switches the activation policy between `.regular` and `.accessory` at runtime.
- `NSMicrophoneUsageDescription` explains the microphone request.
