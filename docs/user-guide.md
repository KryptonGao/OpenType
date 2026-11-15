# User Guide

## Modes

OpenType has four ways to turn speech into text. All of them share the same pipeline (record, recognize, process, insert); they differ in the final model step.

| Mode | How to start | What the model does |
| --- | --- | --- |
| Dictation | Tap `⌃⌥ Space`, tap again to finish | Removes filler words, fixes errors, adds punctuation. Skipped in Raw mode. |
| Voice translation | Tap `⌃⌥ T`, tap again to finish | Cleans up and translates into the target language. |
| Say It for Me | Hold `⌃⌥ Space`, release to finish | Works out what you mean, then refines, completes and organizes it into a message you can send as is. |
| Translate & Say It for Me | Hold `⌃⌥ T`, release to finish | The same, written directly in the translation target language. |

Both shortcuts can be changed.

### Dictation

Speak naturally. When you finish, filler words and false starts are removed, self-corrections resolve to the final meaning, and punctuation is added. Names, numbers and technical terms are preserved. The model is told not to answer questions in what you said and not to translate.

### Voice translation

Your speech is cleaned up and translated into the target language. Fifteen languages are supported: English, Simplified Chinese, Traditional Chinese, Japanese, Korean, French, German, Spanish, Portuguese, Italian, Russian, Arabic, Thai, Vietnamese and Indonesian.

- Set the default under **Settings → Translation**.
- Switch language temporarily in the overlay while recording. The popup is available until processing begins.
- Portuguese offers Brazil or Portugal wording; Traditional Chinese offers Taiwan or Hong Kong & Macau wording.
- If translation fails, untranslated text is never inserted. The recognized text stays in the overlay so you can copy it.

### Say It for Me

For when you know roughly what you want to say but not how to word it.

1. Press and hold the dictation shortcut. After about 0.45 seconds the overlay switches to "Say It for Me" and you hear a soft tick.
2. Keep holding and speak.
3. Release to finish.

If you release before the threshold, it stays ordinary dictation.

The result is written in your voice and in the language you spoke. For example, "Tell my teacher I have a fever and need a day off tomorrow" becomes a complete, polite leave request, and "Ask how to fix this error" becomes a question that spells out the goal, conditions and expected answer. The model never invents names, numbers, dates or links you did not mention, and it does not answer questions in your speech; it only helps you say them.

You can edit the prompt and turn long-press triggering off under **Settings → Say It for Me**.

#### Web search

Say It for Me can optionally look facts up before writing. It is DeepSeek only, uses its own API key, and is off by default. See [Services Reference](services-reference.md#web-search-for-say-it-for-me) for how it works.

| Eagerness | Behavior |
| --- | --- |
| 0% | Same as off |
| 1 to 33% | Conservative: no thinking mode, searches only when asked to verify something |
| 34 to 66% | Moderate: searches when it is unsure about a concrete fact |
| 67 to 100% | Eager: searches whenever concrete real-world facts appear |

While searching, the overlay shows live progress ("Searching … · N results found · M pages read"). After insertion it reports how many searches were made, or that the model did not search.

### Translate & Say It for Me

Hold the translation shortcut. It behaves like Say It for Me, but the finished text is written in the translation target language. Language and regional wording can be switched in the overlay until processing begins.

## Shortcuts

| Action | Default |
| --- | --- |
| Dictation | Tap `⌃⌥ Space` to start, tap again to finish |
| Say It for Me | Hold `⌃⌥ Space`, release to finish |
| Voice translation | Tap `⌃⌥ T` to start, tap again to finish |
| Translate & Say It for Me | Hold `⌃⌥ T`, release to finish |
| Cancel | `Esc` while speaking or processing; nothing is inserted |

Change the dictation shortcut under **Settings → General** and the translation shortcut under **Settings → Translation**: click the field and press the new keys. The translation shortcut can be cleared to disable it.

A shortcut can be:

- A key combination such as `⌃⌥ Space`.
- A single key, such as `F5`.
- A lone modifier key. Left and right sides are distinguished (for example right `⌥`), and `fn` is supported.

Rules and caveats:

- A modifier-only shortcut fires once on **release**, and only if no other key or mouse button was pressed while it was held. That keeps `⌘C` or `⌥`-click from triggering dictation; just tap it.
- A plain character key without any modifier is swallowed entirely by the shortcut, so you can no longer type that character. Pair it with a modifier. `F1` to `F20` are unaffected.
- `Esc` is reserved as the cancel key and cannot be assigned.
- The translation shortcut must differ from the dictation shortcut.
- Long-pressing works for every kind of shortcut. For a modifier-only shortcut the long press itself starts the session.
- To use `fn`, set the system action for pressing fn alone to "Do Nothing" under **System Settings → Keyboard**.
- Shortcuts do not work while macOS Secure Event Input is active (for example while a password field has focus).

## The overlay

A small floating panel appears at the bottom or top center of the screen (configurable). It never takes focus away from your app.

- **Connecting / Recording**: a live volume waveform and the recognized text, with confirmed text in normal weight and a lighter, not-yet-stable tail.
- **Finalizing / Processing / Inserting**: progress while the final transcript arrives, the model runs, and the text is written.
- **Success**: a brief confirmation, then it closes. If something happened along the way (for example the model failed and the raw text was used), a note stays a little longer.
- **Manual copy**: when automatic insertion is impossible, the result stays in the overlay with a **Copy Text** button.
- **Error**: a message. If any text was already recognized, it is kept so you can copy it.

Overlay options under **Settings → General**: position, material (blur or liquid glass), a minimal capsule mode with its own material, and optional sound feedback.

## Text insertion

OpenType tries three tiers in order:

1. **Accessibility direct write**: sets the selected text of the focused control, then verifies the content actually changed.
2. **Simulated paste**: puts the text on the clipboard, sends `⌘V`, then restores your previous clipboard contents (only if nothing else changed the clipboard in the meantime). The temporary clipboard entry is marked transient so clipboard managers skip it.
3. **Manual copy**: the overlay shows the text with a **Copy Text** button.

Safety rules:

- It never writes into password fields or while Secure Event Input is on.
- It never writes into an app or control other than the one you started in. If you switched away, the result is copied to the clipboard and a notification tells you to press `⌘V`.
- It never presses Return or submits anything for you.
- You can turn automatic insertion off under **Settings → General → Text Insertion**; every result then goes to manual copy.

## Main window

Open it from the menu bar (**Open Main Window**), by clicking the Dock icon, or with `⌘,` for settings. It has a native sidebar with five sections.

- **Home**: typing statistics for the last 7, 30 or 90 days (including words per minute, with an all-time comparison), a daily token-usage trend, and a per-model table of calls and input / output tokens. Everything is computed locally. Token counts come from what each AI service reports; services that report none are not counted, and speech recognition is billed by duration, not tokens.
- **History**: every session, searchable by text or model, filterable by mode, with copy and delete. A **Save text** switch controls whether the text is kept, and you can clear only the texts (keeping statistics) or everything. Each record shows the raw and final text (when saved), the mode, model, word count, token usage and whether the text was inserted at the cursor or needs manual copy.
- **Dictionary**: built-in packs and your own entries. See [Dictionary](dictionary.md).
- **Presets**: prompt presets and per-app rules. See [Presets and per-app rules](#presets-and-per-app-rules).
- **Settings**: six tabs described below.

## Presets and per-app rules

A **preset** is a named way of handling what you say: its own prompt, plus a few switches. Open the **Presets** tab to edit them. OpenType ships five, and you can add, duplicate and delete your own (the **Restore Built-in Presets** button brings back deleted built-in ones).

| Preset | Kind | What it does |
| --- | --- | --- |
| Everyday Clean-up | Clean up | The default. Uses the active AI profile's prompt, so it behaves exactly as before presets existed. |
| Casual Chat | Clean up | Short and conversational, no full stop at the end. |
| Work Email | Say It for Me | Turns what you say into a work email body. |
| Code & Tech Questions | Clean up | Keeps identifiers and terms as spoken, coding dictionary packs on. |
| Terminal Commands | Command | Turns your request into one shell command. |

Each preset has a kind. *Clean up* tidies the text (and honours the AI processing level). *Say It for Me* writes the speech up as finished text and always needs the AI. *Command* writes a single-line shell command and always needs the AI; it is only typed, **never run**: Return is never pressed and the command is flattened to one line so pasting it cannot start anything by itself. Clean-up presets can also **remove the final full stop**; this is applied after the AI step, so it also works in Raw mode or when the AI fails. A preset can also switch on **dictionary packs** that are off on the Dictionary page.

**Which preset is used.** When a recording starts, OpenType looks at the frontmost app. If an *app rule* exists for it, that rule's preset is used; otherwise the default preset is. There are no app rules at first: you choose the apps yourself. On the **App Rules** page, click **Add App**, pick one or several apps in the Applications folder (the panel opens there), and choose a preset for each. For example, Slack or WeChat → Casual Chat, Xcode or Cursor → Code & Tech Questions, Terminal or iTerm2 → Terminal Commands. Change a rule's preset any time, delete rules one by one (or **Remove All**), or switch automatic matching off. You can also:

- switch the default preset from the menu bar (**Preset**), where **Match by App** turns the rules on and off;
- change the preset for a single recording from the **Preset** row of the overlay, until processing begins.

Translation never uses presets. Holding the shortcut ("Say It for Me") keeps using the Say It for Me prompt from Settings, unless the preset in use is itself a Say It for Me preset.

## Menu bar

The icon changes with state (idle, recording, busy, paused). The menu lets you:

- see the current dictation and translation shortcuts
- pause all shortcuts
- switch the default preset and turn per-app matching on or off
- check Microphone, Accessibility and Input Monitoring status, and re-check them (it also warns when the global shortcuts are not active)
- open the main window, History or Settings (`⌘,`)
- check for updates, or install one that is ready
- quit (`⌘Q`)

By default the app has no Dock icon; enable one under **Settings → General**.

## Settings

| Tab | Contents |
| --- | --- |
| General | Launch at login, Dock icon, software updates, interface language, dictation shortcut and pause, overlay position / material / minimal mode, sound feedback, automatic insertion |
| Speech Recognition | Provider, model, region, Workspace ID, custom `wss://` address, default language, sentence splitting (VAD threshold and silence duration), recognizer-side polishing, API keys, connection test |
| AI Processing | AI post-processing switch, processing level, fallback to raw text on failure, profiles (format, Base URL, model, timeout, reasoning effort, system prompt, API key), connection test |
| Translation | Default target language, regional wording, translation shortcut |
| Say It for Me | Long-press trigger, prompt, web search switch, DeepSeek key, search eagerness, connection test |
| Privacy & Permissions | Permission status and shortcuts to System Settings, the running app's location, diagnostic logging, Clear Temporary Data |

### Interface language

The UI is available in English, Simplified Chinese, Traditional Chinese (Taiwan), Japanese and Korean. By default it follows the system language and falls back to English. Change it under **Settings → General → Interface Language**; the change takes effect after restarting the app.

### Fallback behavior

With **Fall back to raw ASR text when AI fails or times out** on (the default), a failed cleanup inserts the recognized text and shows a note. Translation never falls back, because inserting untranslated text would be wrong; the recognized text is kept in the overlay instead. Say It for Me falls back only when it is not translating.

## Updates

OpenType checks GitHub Releases for newer versions: shortly after launch and then whenever the last check is more than six hours old. You can also check manually from the menu bar or **Settings → General**.

- **Check for updates automatically** is on by default.
- **Download and install updates automatically** is off by default.
- When an update is found, a notification appears (once per version). Installing downloads the DMG, verifies it, and swaps the app. If a dictation is in progress, installation waits until it finishes.

The install steps and safety checks are described in [Releasing](releasing.md#how-the-in-app-updater-works).

## Data on disk

| Data | Location |
| --- | --- |
| API keys | `~/.opentype/credentials.json` |
| History | `~/Library/Application Support/OpenType/history.json` |
| Dictionary settings and custom entries | `~/Library/Application Support/OpenType/dictionary.json` |
| Presets and app rules | `~/Library/Application Support/OpenType/presets.json` |
| Preferences | The app's `UserDefaults` (`com.opentype.OpenType`) |

See [Privacy and Security](privacy-and-security.md) for details.
