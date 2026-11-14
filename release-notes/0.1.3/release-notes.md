[English](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ko.md)

# OpenType 0.1.3 (4)

This release adds **in-app updates**: OpenType can check GitHub Releases on its own, download and verify the new DMG, and install it, so you no longer have to replace the app by hand.

> **Requirements: macOS 26.0+ · Apple Silicon (arm64)**

## What's new

- **In-app updates**: check for new versions on GitHub Releases from Settings; when one is found, download the DMG, verify it, and install it right from the app.
- **Automatic check and install**: optionally check for updates automatically, and optionally download and install a new version as soon as it is found.
- **Menu bar prompt**: the menu bar menu shows the update status and an entry point to update.
- Added localized strings for the updater (简体中文, 繁體中文, English, 日本語, 한국어) and unit tests.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64) only**; Intel Macs are not supported.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

Download `OpenType-0.1.3-arm64.dmg` (or `OpenType-0.1.3-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version. From 0.1.3 on, later versions can be updated from within the app.

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
| `OpenType-0.1.3-arm64.dmg` | Disk image; drag into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.3-arm64.zip` | Archive; unzip to get `OpenType.app` (macOS 26.0+, arm64) |
