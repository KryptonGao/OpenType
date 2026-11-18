[English](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.ko.md)

# OpenType 0.1.11 (12)

Screen Ask now supports Bing for image search.

> **macOS 26.0+ · Apple Silicon (arm64)**

## What's new

In **Settings → Screen Ask → Image search engine**, choose **Google** or **Bing**. Google is the default. Click **Image Search** beside the selected region to send the image to the chosen engine in your default browser.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64)**.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security. Screen Ask also needs **Screen Recording**.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

If you are on 0.1.3 or later, update from within the app (Settings → Check for Updates). Otherwise download `OpenType-0.1.11-arm64.dmg` (or `OpenType-0.1.11-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version.

Gatekeeper blocks this self-signed build on first launch because it lacks Apple notarization. Click "Open Anyway" in System Settings → Privacy & Security, or run the following command in Terminal.

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> As long as upgrades are signed with the same certificate, your Accessibility / Input Monitoring grants are kept.

## Downloads

| File | Description |
|---|---|
| `OpenType-0.1.11-arm64.dmg` | Disk image. Drag the app into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.11-arm64.zip` | Archive. Unzip to get `OpenType.app` (macOS 26.0+, arm64) |
