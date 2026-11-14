[English](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ko.md)

# OpenType 0.1.4 (5)

This release redesigns the main window with a **native sidebar layout**, so OpenType looks and feels more like a regular macOS app.

> **Requirements: macOS 26.0+ · Apple Silicon (arm64)**

## What's new

- **Native sidebar layout**: the main window is now a sidebar with Home, History, and Dictionary, followed by a Settings section holding the six settings pages. The segmented switcher inside the settings tab is gone.
- **Home**: a hotkey status card at the top, usage stats grouped in one framed row, and the time-range picker moved to the window toolbar.
- **History and Dictionary**: native search field and toolbar items, smaller switch controls, and dictionary packs shown in a grouped form.
- **Menu bar and overlay**: the menu bar menu now has SF Symbols and status icons; the overlay card has larger rounded corners and a status icon.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64) only**; Intel Macs are not supported.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

If you are on 0.1.3 or later, update from within the app (Settings → check for updates). Otherwise download `OpenType-0.1.4-arm64.dmg` (or `OpenType-0.1.4-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version.

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
| `OpenType-0.1.4-arm64.dmg` | Disk image; drag into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.4-arm64.zip` | Archive; unzip to get `OpenType.app` (macOS 26.0+, arm64) |
