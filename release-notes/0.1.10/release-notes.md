[English](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ko.md)

# OpenType 0.1.10 (11)

This release adds **Screen Ask**: select a region of your screen and ask about it.

> **Requirements: macOS 26.0+ · Apple Silicon (arm64)**

## What's new

- **Screen Ask**: press the global shortcut (default ⇧⌘6, changeable under Settings → Screen Ask) and the screen dims. Drag a selection box over the area you want to ask about; you can still adjust it with its 8 handles, move it, or draw a new one. A glass panel beside the selection answers your questions about the region with streamed Markdown replies. Ask by typing or by voice, and use the shortcut button to search the region on Google Images. Answered questions are recorded in History as text only; the screenshot is never saved.
- **Web search settings are now shared**: web search and page reading moved to Settings → AI Processing (DeepSeek only, with its own API key). “Say It for Me” and “Screen Ask” follow this shared setting by default, and each can have its own on/off and eagerness.
- **Screen Recording permission** is required for Screen Ask; macOS will ask the first time you use it.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64) only**; Intel Macs are not supported.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security. Screen Ask also needs **Screen Recording**.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

If you are on 0.1.3 or later, update from within the app (Settings → check for updates). Otherwise download `OpenType-0.1.10-arm64.dmg` (or `OpenType-0.1.10-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version.

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
| `OpenType-0.1.10-arm64.dmg` | Disk image; drag into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.10-arm64.zip` | Archive; unzip to get `OpenType.app` (macOS 26.0+, arm64) |
