[English](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.ko.md)

# OpenType 0.1.7 (8)

This release adds **Writing Tools**, a floating panel for working on text anywhere, and **Voice Rewrite**, which edits your selection from a spoken instruction.

> **Requirements: macOS 26.0+ · Apple Silicon (arm64)**

## What's new

- **Writing Tools (⌃⌥W)**: a floating panel next to your selected text (or the caret) with Proofread (changes shown inline), Rewrite, tone changes, Summary / Key Points / List / Table, Translate, and a free-form command box you can type or speak. With nothing selected it becomes **Compose**, with two buttons: Generate (plain text, no Markdown marks) and **Generate Markdown** (headings, lists, bold, tables…). Results can be refined, regenerated, copied, and replaced or inserted back into the app (⌘Z undoes it). It has its own shortcut, on/off switch, profile, model ID and reasoning effort in Settings, plus its own panel material (frosted blur by default). Drag the panel by its card; it opens next to the mouse pointer.
- **Streaming answers**: every Writing Tools reply now streams in as the model writes it, fading in a sentence at a time. A Stop button cancels it, a broken or stopped stream never replaces your selection, and nothing can be applied or copied until the result is complete.
- **Voice Rewrite**: with text selected when you start dictating, your speech is treated as an instruction (for example "make the tone softer" or "translate to Japanese"). The selection and the instruction go to the LLM and the result replaces the selection; if anything fails, the selection is left untouched. Chromium / Electron apps (Claude, VS Code, Slack, Chrome…) now expose their selection correctly.
- **Translate with the app's preset**: a new option (off by default) makes translation follow the preset for the current app: its tone and style, its dictionary packs, and the trailing-period rule. Command presets such as Terminal Command Generation are never used. The overlay shows the preset capsule and picker when this applies.
- **Presets**: the half-width punctuation option is gone; the model now picks punctuation itself (half-width for Latin text, full-width for Chinese).
- **Fixes**: long Writing Tools results scroll inside their own box and no longer poke out of the rounded card; softer card shadow, equal-sized format cards, aligned table borders, and no blue focus rings; Writing Tools has its own icon.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64) only**; Intel Macs are not supported.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

If you are on 0.1.3 or later, update from within the app (Settings → check for updates). Otherwise download `OpenType-0.1.7-arm64.dmg` (or `OpenType-0.1.7-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version.

This build is signed with a self-signed certificate and is not notarized by Apple, so Gatekeeper will block it on first launch. Allow it with either of these:

- Click "Open Anyway" in System Settings → Privacy & Security;
- or run this in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> As long as upgrades are signed with the same certificate, your Accessibility / Input Monitoring grants are kept.

## Downloads

| File | Description |
|---|---|
| `OpenType-0.1.7-arm64.dmg` | Disk image; drag into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.7-arm64.zip` | Archive; unzip to get `OpenType.app` (macOS 26.0+, arm64) |
