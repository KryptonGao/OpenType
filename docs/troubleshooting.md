# Troubleshooting

Start with **Settings → Privacy & Permissions** and the menu bar's **Permission Status** section. Most problems are permissions.

## Shortcuts

### Pressing the shortcut does nothing

1. Check the menu bar menu. If it says the global shortcut is not active, a permission is missing: Accessibility and Input Monitoring are both required (plus Microphone to record).
2. Make sure **Pause global shortcuts** is off.
3. Secure Event Input blocks all global shortcuts. It is on while a password field has focus, and some apps leave it on by accident. Click into a normal text field, or quit the app that is holding it.
4. Confirm the translation shortcut is not identical to the dictation shortcut; a duplicate disables the translation one.
5. Click **Restart OpenType** in the permissions tab.

### Permissions are on, but the app says "not granted"

macOS records Accessibility and Input Monitoring grants per signing identity. An ad-hoc signed build changes identity on every rebuild, so the switch looks on but the grant is stale.

1. Click **Restart OpenType**.
2. If that does not help, in **System Settings → Privacy & Security** select OpenType in the Accessibility and Input Monitoring lists, remove it with **−**, then add it again with **+** (or run it once more so macOS offers it).
3. If you build from source, sign with a stable certificate. See [Development](development.md#signing).

### A modifier-only shortcut triggers by accident, or never triggers

A modifier-only shortcut fires on release, and only if no other key or mouse button was pressed while it was held. If it never fires, you probably pressed another key during the hold. If you use `fn`, set the system action for the fn key to "Do Nothing" under **System Settings → Keyboard**.

### I can no longer type a letter

A shortcut with no modifier on an ordinary character key swallows that key. Change the shortcut, preferably to a combination with a modifier. `F1` to `F20` are not affected.

### Say It for Me does not start on long press

- Check that **Hold the shortcut to trigger “Say It for Me”** is on under **Settings → Say It for Me**.
- Hold for at least about 0.45 seconds. A shorter press is ordinary dictation.
- Say It for Me needs a configured AI profile (or the DeepSeek key when web search is on).

## Recording and recognition

### "No microphone permission" or no waveform

Grant Microphone access in **System Settings → Privacy & Security → Microphone**. If the waveform is flat, check the input device in **System Settings → Sound**. An unplugged or switched device ends the session with what was already captured.

### A very short tap does nothing

Recordings shorter than about 0.2 seconds are treated as accidental and end silently. The same happens when no speech was recognized: the AI step is skipped and nothing is inserted.

### Speech recognition authentication failed

- **Bailian**: check the API key and the **Workspace ID**, and that the region (Beijing or Singapore) matches where the key was issued. Use **Test Connection**.
- **DeepSeek**: check the API key. Note that **Test Connection** sends a short silent request and is billed as one second.

### The connection timed out, or was rate limited (429)

The service did not answer within about 10 seconds to connect, or is throttling you. Retry shortly. Words recognized before a disconnect are kept in the overlay for copying.

### No live text while speaking

That is expected with the DeepSeek provider: it recognizes the whole recording after you finish. Use Bailian for streaming text.

### Finalizing timed out

The service took too long to return the last sentence (10 seconds for Bailian, 90 seconds for DeepSeek). OpenType uses whatever was recognized and adds a note. Very long recordings with DeepSeek take longer to upload.

## AI processing

### "AI processing failed, raw text used"

The model call failed or timed out and the fallback inserted the recognized text. Check the profile's Base URL, model ID and key with **Test Connection**. Raise the **timeout** if the model is slow; Say It for Me writes longer output, so give it more time.

To get an error instead of a fallback, turn off **Fall back to raw ASR text when AI fails or times out**. The recognized text is then kept in the overlay for copying.

### Translation failed and nothing was inserted

By design, untranslated text is never inserted. Copy the recognized text from the overlay and retry after fixing the profile.

### Base URL errors

The Base URL must be `https`. Enter the base only (for example `https://api.openai.com/v1`); a trailing `/responses`, `/chat/completions` or `/messages` is stripped automatically.

### Web search does not work

- Enter a DeepSeek key under **Settings → Say It for Me**. Without it you get an error rather than a silent switch to another model.
- Set the eagerness slider above 0%.
- Web search always uses DeepSeek, not your selected profile.
- It has a fixed 180-second timeout; searching and reading pages takes time.

## Insertion

### The text appeared in the overlay instead of the app

Automatic insertion was not possible. The overlay shows why: the target is a password field, Secure Event Input is on, Accessibility is not granted, focus moved to another app or control, or the control does not support insertion. Click **Copy Text** and paste manually. If you moved to another app, the text is already on the clipboard.

### Some apps ignore the insertion

A few apps (certain Electron apps, terminals, remote desktops) do not expose settable text through Accessibility. OpenType then falls back to simulated `⌘V`, and finally to manual copy. If paste does not land, make sure the field is focused when the result arrives.

### My clipboard changed

Simulated paste temporarily replaces the clipboard and restores it about 0.6 seconds later, but only if nothing else changed it in the meantime. If you copied something in that window, your newer copy is kept.

## Updates

### "No permission to replace the current app"

The app must live in a writable location outside a read-only volume or App Translocation. Move `OpenType.app` to `/Applications` and relaunch it; opening it directly from a downloaded DMG or a quarantined Downloads folder triggers translocation.

### Checksum or signature errors

The downloaded file did not match the release's size or digest, or the new app does not share the running app's signing identity. Retry; if it persists, download the DMG manually from the Releases page.

## Collecting diagnostics

1. Turn on **Enable diagnostic logging** in **Settings → Privacy & Permissions**.
2. Reproduce the problem.
3. Read the log:

   ```bash
   log show --last 5m --predicate 'subsystem == "com.opentype.OpenType"' --info
   ```

The log contains phase timings and state names only, never speech, text or keys, so it is safe to share. Turn logging off again when finished.

## Resetting

- **Clear Temporary Data** in the Privacy tab cancels any pending session and discards leftover overlay text.
- To reset all preferences, quit the app and run `defaults delete com.opentype.OpenType`.
- To remove saved keys, delete `~/.opentype/credentials.json`.
- To remove history and dictionary data, delete `~/Library/Application Support/OpenType/`.
