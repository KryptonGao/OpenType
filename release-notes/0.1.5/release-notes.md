[English](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ko.md)

# OpenType 0.1.5 (6)

This release adds **prompt presets with per-app rules** and lets you **lock the microphone input device**.

> **Requirements: macOS 26.0+ · Apple Silicon (arm64)**

## What's new

- **Presets**: the single fixed prompt is replaced by manageable presets in the new **Presets** tab. Each preset has its own prompt, an optional trailing-period removal, half-width punctuation, and the dictionary packs to switch on. Built-in presets: Everyday Clean-up (the previous behavior), Casual Chat, Work Email, Code & Tech Questions, and Terminal Commands. You can create your own and restore the built-in ones.
- **App Rules**: OpenType matches the frontmost app by bundle identifier when a session starts and uses the preset you assigned to it. Add apps from the Applications folder (none are pre-filled). You can switch the default preset and app matching from the menu bar, or change the preset for a single recording in the overlay.
- **Terminal Commands**: command presets are flattened to a single line and are only typed in, never run.
- **Microphone lock**: choose a specific input device (built-in, USB, Bluetooth, Continuity, etc.) in Settings → Speech Recognition or from the menu bar. Locking to a built-in or external microphone keeps AirPods and other Bluetooth headphones out of low-quality call mode while you listen to music or are in a meeting. OpenType warns you if the chosen microphone is Bluetooth or disconnected.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64) only**; Intel Macs are not supported.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

If you are on 0.1.3 or later, update from within the app (Settings → check for updates). Otherwise download `OpenType-0.1.5-arm64.dmg` (or `OpenType-0.1.5-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version.

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
| `OpenType-0.1.5-arm64.dmg` | Disk image; drag into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.5-arm64.zip` | Archive; unzip to get `OpenType.app` (macOS 26.0+, arm64) |
