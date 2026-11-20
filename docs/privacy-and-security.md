# Privacy and Security

OpenType has no server of its own and no account system. This page lists every place your data goes and every place it is stored, so you can judge for yourself.

## What leaves your Mac

| Data | Sent to | When |
| --- | --- | --- |
| Microphone audio | The speech recognition service you chose: Alibaba Cloud Bailian (streamed while you speak), or DeepSeek (uploaded as one recording after you finish) | During a session |
| Recognized text | The LLM service configured in your active AI Processing profile | After recognition, unless Raw mode is used for plain dictation |
| Recognized text | DeepSeek (`api.deepseek.com`), using its own key | Say It for Me with web search on. DeepSeek's servers then search the web on your behalf. |
| Selected screen image and question | The AI service configured for Screen Ask | When you submit a question with Web Search off. |
| Selected screen image and question | DeepSeek (`deepseek-flash`), using the Web Search key | When you submit a question with Web Search active. DeepSeek performs any web searches and page reads on its servers. A search eagerness of 0% is equivalent to Web Search off. |
| Selected screen image | Google Lens or Bing, via your default browser | When you choose Image Search. The browser opens a temporary local HTML file that submits the image to the selected engine. |
| Version check | GitHub (`api.github.com`) and the release asset download | Automatic or manual update checks, if enabled |

Screen Ask follow-up requests include the original image again as part of the conversation context.

OpenType sends no analytics, crash reports, or telemetry. Third-party services handle the data they receive under their own privacy terms.

## What is stored on your Mac

| Data | Location | Notes |
| --- | --- | --- |
| API keys | `~/.opentype/credentials.json` | Plaintext JSON. Directory mode `0700`, file mode `0600`. |
| History | `~/Library/Application Support/OpenType/history.json` | Text and counters, including Screen Ask question and answer text when **Save text** is on. Screenshots aren’t saved in History. The history file is never uploaded. Up to 5000 records. |
| Image Search | `OpenType-ImageSearch` in the system’s per-user temporary directory | HTML containing the selected image. Directory mode `0700`, file mode `0600`. OpenType normally removes the file after about two minutes and checks for expired files at launch and before another Image Search. |
| Dictionary | `~/Library/Application Support/OpenType/dictionary.json` | Settings and your custom entries. |
| Preferences | The app's `UserDefaults` | Shortcuts, provider choices, profiles (without keys), overlay options. |
| Update downloads | `~/Library/Caches/com.opentype.OpenType/Updates` | Temporary; cleaned up at launch. |

**Never stored:** raw audio. Recordings exist only in memory while a session runs. The DeepSeek recognizer keeps the PCM in memory until it uploads it.

### API keys

- Keys are stored as plaintext JSON on purpose. The Keychain binds access to the app's code signature, so every upgrade of a self-signed build prompted for the login password. Anyone or anything that can read your home folder can read the file, so treat it like `~/.ssh`.
- The Settings UI only shows "Saved" and never reads a key back into a text field.
- Keys are never written to `UserDefaults`, logs or error messages. Error text passes through a redactor that masks any known secret.
- Keys that older versions left in the Keychain are migrated into the file automatically at first launch, and the Keychain items are removed.
- Do not commit `~/.opentype/credentials.json` anywhere.

### History

- Recognized and cleaned-up text is saved by default so you can search and copy it later. Turn it off with **Save text** on the History page.
- **Clear text only (keep statistics)** removes the texts but keeps the counters; **Clear all records and statistics** removes everything.
- The Home statistics use only counts, character or word counts, durations and token counts.

### Logs

Diagnostic logging is off by default. When enabled in **Settings → Privacy & Permissions**, it records only phase timings and state names (for example how long the model step took) to the unified log under the subsystem `com.opentype.OpenType`. It never logs speech, text or credentials.

## Network safety

- Only certificate-validated HTTPS and WSS are accepted. Base URLs for LLM profiles must be `https`.
- A Bailian Workspace ID is format-checked (letters, digits, hyphens). Your key is only ever sent to the Alibaba Cloud host derived from it, or to a custom `wss://` address you typed yourself. URLs with embedded user names or passwords are rejected.
- Credentials travel in request headers (`Authorization`), never in URLs or query strings.
- Sessions use ephemeral `URLSession` configurations, so nothing is cached to disk by the networking layer.

## Text insertion safety

- OpenType never writes into password fields or while macOS Secure Event Input is on.
- It records the focused app and control when a session starts. If focus moved elsewhere by the time the result is ready, nothing is written there; the text goes to your clipboard and a notification explains.
- Simulated paste backs up your clipboard and restores it afterwards, only when nothing else touched the clipboard in between. The temporary entry is flagged transient (`org.nspasteboard.TransientType`) so clipboard managers skip it.
- Text insertion never presses Return or submits a form.

## Permissions

| Permission | Used for | Scope |
| --- | --- | --- |
| Microphone | Recording while a session runs | Only active during a session |
| Accessibility | Reading which control has focus and writing text into it; posting `⌘V` for paste fallback | Only around insertion |
| Input Monitoring | A global event tap that watches for your shortcut and `Esc` | While the app runs. It only reacts to the configured shortcuts, and `Esc` only while a session is visible. |
| Screen Recording | Capturing the selected region for Screen Ask or Image Search | When you select a region |

The app is not sandboxed (it needs the event tap and Accessibility), but it requests only the microphone entitlement (`com.apple.security.device.audio-input`).

## Updates

The in-app updater downloads the release DMG from GitHub Releases and verifies it before replacing the app:

1. File size and, when GitHub provides it, the SHA-256 digest.
2. The app inside the image has the same bundle identifier and the announced version.
3. A strict code signature check. When the running app has a real signing identity, the new app must satisfy the same designated requirement (same bundle ID and certificate).

Details are in [Releasing](releasing.md#how-the-in-app-updater-works). Both automatic checks and automatic installation can be turned off in **Settings → General**.

## Self-signed builds

Releases are signed with a self-signed certificate rather than an Apple Developer ID, so they are not notarized and Gatekeeper asks you to approve the first launch. You can verify what you run by building from source (see [Development](development.md)).
