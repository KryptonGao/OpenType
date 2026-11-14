# Development

How to build, test, package and change OpenType. For how the code is organized, read [Architecture](architecture.md) first.

## Prerequisites

- macOS 26 or later on Apple Silicon
- Xcode with the macOS 26 SDK
- Swift 6 language mode (set in the project)
- `gh` (GitHub CLI), only for [releases](releasing.md)

There are no third-party dependencies and no package manager step.

## Building

Open `OpenType.xcodeproj` in Xcode and run the `OpenType` scheme, or build from the command line:

```bash
xcodebuild build -project OpenType.xcodeproj -scheme OpenType -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData
```

The product is at `build/DerivedData/Build/Products/Release/OpenType.app`. The bundle identifier is `com.opentype.OpenType`, and the version comes from `MARKETING_VERSION` (for example `0.1.4`) and `CURRENT_PROJECT_VERSION` (the build number, for example `5`) in the project settings.

## Signing

The project defaults to ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`). That is fine for compiling, but it breaks permissions:

- An ad-hoc signature's designated requirement is the code hash (`cdhash`), which **changes on every build**.
- macOS records Accessibility and Input Monitoring grants per signing identity. After an ad-hoc rebuild the System Settings toggles still look on, but the app has no permission and global shortcuts stop working.

So re-sign every locally packaged build with a **stable** certificate. The project uses a self-signed code-signing certificate named `OpenType Self-Signed` in the login keychain:

```bash
codesign --force --sign "OpenType Self-Signed" \
  --options runtime --entitlements OpenType/OpenType.entitlements build/OpenType.app
```

Verify the result is no longer `cdhash`:

```bash
codesign -d -r- build/OpenType.app
```

Notes:

- If you do not have that certificate, create your own self-signed code-signing certificate in Keychain Access, or sign with your Apple Developer identity, and use it consistently. A different identity means re-granting permissions once.
- Keep a backup of the `.p12`, and never commit it.
- If the certificate is lost or replaced, every user (and your machine) must re-grant Accessibility and Input Monitoring.
- The in-app updater only accepts a new build whose signature satisfies the running app's designated requirement, so release builds must be signed with the same certificate as the version they replace.
- A self-signed app cannot pass Gatekeeper. For a future without the first-launch warning, use a Developer ID Application certificate and notarize with `notarytool`.

## Packaging a local build

After every code change, once the build and tests pass, package a fresh Release app and re-sign it:

```bash
xcodebuild build -project OpenType.xcodeproj -scheme OpenType -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
&& rm -rf build/OpenType.app \
&& cp -R build/DerivedData/Build/Products/Release/OpenType.app build/OpenType.app \
&& codesign --force --sign "OpenType Self-Signed" \
     --options runtime --entitlements OpenType/OpenType.entitlements build/OpenType.app
```

The output is `build/OpenType.app` (`build/` is git-ignored). Verify the binary is arm64-only with `lipo -archs build/OpenType.app/Contents/MacOS/OpenType`.

## Testing

```bash
xcodebuild test -project OpenType.xcodeproj -scheme OpenType -destination 'platform=macOS'
```

Tests use [Swift Testing](https://developer.apple.com/documentation/testing) (`@Test`, `#expect`) and live in `OpenTypeTests/`:

| File | Covers |
| --- | --- |
| `OpenTypeTests.swift` | Transcript aggregation, ASR configuration and `session.update` content, DeepSeek ASR segmenting and WAV building, request building, response parsing and error mapping for all three LLM protocols, the web-search progress parser, hotkey matching, modifier-only shortcuts and long-press detection, `HotkeyConfig` validation, settings persistence, security checks (URL and credential handling), text metrics, token usage parsing, usage statistics, history storage, overlay stress, app language storage, and end-to-end coordinator flows |
| `DictionaryTests.swift` | Matcher (hints and replacement), prompt addendum, store persistence, built-in pack loading |
| `UpdateTests.swift` | Version comparison and GitHub release parsing |

### How end-to-end tests work

`DictationSessionCoordinator` accepts all collaborators through its initializer. Tests pass fakes for audio capture, the ASR factory, the LLM factory, the text inserter, the notifier, the overlay and the permission checker, with an `InMemoryCredentialStore` and an isolated `UserDefaults` suite. They then call `beginSession` and `stopRecording` and assert on the resulting state, history record and inserted text. This covers success, raw-text fallback, cancellation, every failure mode, translation and Say It for Me without a microphone, network or Accessibility permission.

### Writing tests

- Keep request builders and response parsers pure so they can be tested directly.
- Test hotkey behavior by calling `HotkeyManager.handle(type:keyCode:flags:isAutoRepeat:)` and `fireLongPress()` rather than installing a real event tap.
- Use `HistoryStore()`, `DictionaryStore(packs: [])` or `fileURL:` pointing at a temporary directory, never the real Application Support folder.
- Never put real keys or real speech in fixtures.

## Project layout

```
OpenType/              Application sources (see Architecture for the breakdown)
OpenTypeTests/         Unit tests
OpenType.xcodeproj/    Xcode project (shared scheme: OpenType)
assets/readme/         Localized README images (hero.<lang>.svg, modes.<lang>.svg)
docs/                  Documentation (this folder) and the static website
release-notes/<ver>/   Per-version release notes in five languages
Design/                App icon and menu bar icon sources (git-ignored)
build/, dist/          Local build and release output (git-ignored)
OpenType PRD.md        Original product requirements (Chinese)
AGENTS.md              Working rules for contributors and coding agents
```

## Conventions

### Commits and branches

Commit directly to `main`. Open a branch and a pull request only when you have been explicitly asked to. Commit messages follow a conventional-commit style, matching the history: `feat(ui): …`, `fix: …`, `docs: …`, `chore: …`, `release: <version> (<build>)`.

### Code style

- Swift 6 strict concurrency. UI-facing state holders are `@MainActor @Observable`.
- Types that cross isolation domains are `Sendable`. Network clients are `actor`s or `Sendable` structs.
- Prefer protocols at seams (`ASRService`, `LLMProvider`, `TextInserting`, `AudioCapturing`, `CredentialStoring`, `UserNotifying`, `OverlayPresenting`) so tests can substitute fakes.
- Every asynchronous continuation in the session pipeline must verify `isCurrent(sessionID)` before touching state.
- Do not write transcripts, audio, or keys to logs or error messages. Use `Diagnostics.log` for timings and state names only, and `Diagnostics.redact` for anything that may echo secrets.
- Never put credentials in URLs. Use headers.

### Localization

- Code strings are Chinese source keys (`String(localized: "…")`, SwiftUI `Text("…")`).
- Every user-visible string needs entries for English, Simplified Chinese, Traditional Chinese, Japanese and Korean in `OpenType/Resources/Localizable.xcstrings`.
- Use the app's own English terms in docs and READMEs (for example "Say It for Me", "Settings → Speech Recognition").

### README and docs

The README exists in five languages: `README.md` (English, the GitHub default), `README.zh-Hans.md`, `README.zh-Hant.md`, `README.ja.md` and `README.ko.md`. When you change user-facing README content, update all five. Each has localized images in `assets/readme/`. The documents in `docs/` are English only.

### Adding a setting

1. Add the property to `SettingsStore` with a `Keys` entry, a default in `init`, and a `didSet` that writes to `UserDefaults`.
2. Read it with a safe fallback: invalid or missing stored values must fall back to the default.
3. Add the control to the right tab in `SettingsView.swift`.
4. Add localized strings.
5. Add a test to `SettingsStoreTests`.
6. Update the [User Guide](user-guide.md) settings table and any relevant doc.

### Adding a secret

Add a constant to `CredentialAccount`, store it through `CredentialStoring` only, and show it in the UI through `SecretField` (which displays "Saved" and never reads the value back).

## Debugging

- Turn on **Enable diagnostic logging** in Settings, then stream timings:

  ```bash
  log stream --predicate 'subsystem == "com.opentype.OpenType"' --info
  ```

  The timing summary shows key-to-capture, connect, ASR finalize, LLM, insert and release-to-inserted durations.
- If shortcuts stop working after a rebuild, the permissions are stale; see [Signing](#signing) and [Troubleshooting](troubleshooting.md#permissions-are-on-but-the-app-says-not-granted).
- Use **Test Connection** in Settings to isolate credential and endpoint problems from pipeline problems.
- `Settings → Privacy & Permissions` shows the path of the running bundle, which helps when several builds exist on disk.

## Website

The static site served from `docs/` is plain HTML, CSS and JavaScript with its own strings in `docs/i18n.js`. It has no build step. Preview it by opening `docs/index.html` or serving the folder:

```bash
python3 -m http.server --directory docs 8000
```
