[English](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.ko.md)

# OpenType 0.1.9 (10)

This release renders model replies as **Markdown**, including tables, code blocks and LaTeX math.

> **Requirements: macOS 26.0+ · Apple Silicon (arm64)**

## What's new

- **Markdown replies**: Writing Tools results (including while they stream in), the pending text in the dictation overlay, and the result in History detail now render Markdown properly: headings, lists, tables, code blocks and LaTeX formulas, instead of raw symbols.
- **Release notes in the update window** use the same renderer, so they now display more reliably.
- **Writing Tools**: the input fields now show the Apple Intelligence icon.

## Requirements

- **macOS 26.0 or later**.
- **Apple Silicon (arm64) only**; Intel Macs are not supported.
- Grant **Microphone**, **Accessibility**, and **Input Monitoring** permissions in System Settings → Privacy & Security.
- You need your own API key for Alibaba Cloud Bailian or DeepSeek (ASR), plus an API key for the LLM service you choose.

## Install and upgrade

If you are on 0.1.3 or later, update from within the app (Settings → check for updates). Otherwise download `OpenType-0.1.9-arm64.dmg` (or `OpenType-0.1.9-arm64.zip`) and drag `OpenType.app` into the Applications folder, replacing the old version.

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
| `OpenType-0.1.9-arm64.dmg` | Disk image; drag into Applications (macOS 26.0+, arm64) |
| `OpenType-0.1.9-arm64.zip` | Archive; unzip to get `OpenType.app` (macOS 26.0+, arm64) |
