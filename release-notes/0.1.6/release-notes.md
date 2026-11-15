[English](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ko.md)

# OpenType 0.1.6 (7)

This release adds a redesigned **update window** and keeps your **data in readable files under `~/.opentype`**.

> **Requirements: macOS 26.0+ · Apple Silicon (arm64)**

## What's new

- **Update window**: checking for updates now opens a small **Software Update** window with the app icon, the new version, and its release notes (rendered Markdown, shown in the UI language). Choose **Skip This Version**, **Remind Me Later**, or **Install Update**; installing switches to a separate progress window with a byte count and Cancel. Up-to-date and error messages use standard system alerts, and a skipped version stays quiet in background checks. The release-notes disclosure in Settings is gone.
- **Data in `~/.opentype`**: all settings (`settings.json`), prompt presets and app rules (`presets.json`), the dictionary (`dictionary.json`), and history (`history.json`) are now plain JSON files in `~/.opentype`, shared by development and release builds and easy to back up or copy to another Mac. Existing settings, presets, and history from earlier versions are migrated automatically, once, on first launch.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64) only**; Intel Macs are not supported.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

If you are on 0.1.3 or later, update from within the app (Settings → check for updates). Otherwise download `OpenType-0.1.6-arm64.dmg` (or `OpenType-0.1.6-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version.

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
| `OpenType-0.1.6-arm64.dmg` | Disk image; drag into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.6-arm64.zip` | Archive; unzip to get `OpenType.app` (macOS 26.0+, arm64) |
