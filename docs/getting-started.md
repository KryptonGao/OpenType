# Getting Started

This guide takes you from nothing to your first dictation.

## Requirements

- macOS 26.0 or later
- Apple Silicon (arm64). The released binary is arm64-only.
- A microphone
- API keys for the services you want to use (see [step 3](#3-configure-the-services)):
  - Speech recognition: an Alibaba Cloud Bailian key (with a Workspace ID), or a DeepSeek key
  - AI text processing: a key for any OpenAI Responses, OpenAI Chat Completions or Anthropic Messages compatible service

OpenType has no account system and no backend of its own. It talks directly to the services you configure.

## 1. Install

### Option A: download a release

1. Download `OpenType-<version>-arm64.dmg` (or the `.zip`) from the [GitHub Releases](https://github.com/KryptonGao/OpenType/releases) page.
2. Drag `OpenType.app` into `/Applications`.
3. Release builds are signed with a self-signed certificate, so Gatekeeper blocks the first launch. Do one of the following:
   - Open **System Settings → Privacy & Security** and click **Open Anyway** next to the OpenType message.
   - Or remove the quarantine flag in a terminal:

     ```bash
     xattr -dr com.apple.quarantine /Applications/OpenType.app
     ```

After the first install, the in-app updater can install later versions for you (see [Updates](user-guide.md#updates)).

### Option B: build from source

Requires Xcode with the macOS 26 SDK. See [Development](development.md#building) for details.

```bash
git clone https://github.com/KryptonGao/OpenType.git
cd OpenType
open OpenType.xcodeproj
```

> Sign with a stable certificate. An ad-hoc signature changes identity on every rebuild, which makes macOS invalidate the Accessibility and Input Monitoring grants (see [Troubleshooting](troubleshooting.md#permissions-are-on-but-the-app-says-not-granted)).

## 2. Grant permissions

OpenType lives in the menu bar (and optionally the Dock). On first launch, open **Settings → Privacy & Permissions** and grant the following. Each one also needs OpenType switched on in **System Settings → Privacy & Security**.

| Permission | Why it is needed |
| --- | --- |
| Microphone | Capture your speech. macOS prompts the first time you record. |
| Accessibility | Write text into other apps' input fields and simulate paste. |
| Input Monitoring | Listen for the global shortcuts. |

Shortcuts start working automatically once the permissions are granted; the app retries every 1.5 seconds in the background. If a switch is on but the app still reports "not granted", click **Restart OpenType**. If that does not help, remove OpenType from the System Settings list and add it again.

## 3. Configure the services

OpenType keeps speech recognition (ASR) and text processing (LLM) separate, so you configure them independently.

### Speech recognition

Open **Settings → Speech Recognition** and pick a provider.

**Alibaba Cloud Bailian (real-time streaming)**

1. Choose the model: `qwen3-asr-flash-realtime` or `qwen-audio-3.1-asr-flash-message`.
2. Choose the region: Beijing or Singapore.
3. Enter your **Workspace ID** and **API key**.
4. Optionally click **Test Connection**.

The Workspace ID may contain only letters, digits and hyphens. The key is only ever sent to the Alibaba Cloud host derived from it, or to a `wss://` address you typed explicitly under the custom address field.

**DeepSeek (whole-recording recognition)**

Enter a DeepSeek API key. This API does not stream, so no live text appears while you speak; the whole recording is uploaded when you finish. Recordings longer than about 110 seconds are split into segments automatically.

### AI processing

Open **Settings → AI Processing**.

1. Create or edit a **profile**:
   - **API format**: OpenAI Responses, OpenAI Chat Completions, or Anthropic Messages.
   - **Base URL**: must be `https`. A trailing `/v1`, `/responses`, `/chat/completions` or `/messages` is normalized so it is never appended twice.
   - **Model ID** and **API key**.
   - Optional **reasoning effort** (for example `low` or `high`); nothing is sent when empty.
   - **Timeout** in seconds. The default profile uses 15 seconds.
2. Optionally click **Test Connection**.
3. Choose a **processing level**:
   - **Raw**: skip the AI entirely and insert the recognized text.
   - **Standard**: remove filler words, fix errors, add punctuation.
   - **Deep cleanup**: also reorder and paragraph the text while preserving meaning.

Voice translation and Say It for Me always call the selected profile, even if AI post-processing is off or Raw is selected.

## 4. Your first dictation

1. Click into any text field (Notes, a browser, a chat app, an editor).
2. Tap `⌃⌥ Space`. A small overlay appears at the bottom of the screen with a live waveform.
3. Speak.
4. Tap `⌃⌥ Space` again. The overlay shows the processing steps, and the text is inserted where your cursor was.

Press `Esc` at any time to cancel; nothing is inserted.

Next: read the [User Guide](user-guide.md) for the other modes and every setting.
