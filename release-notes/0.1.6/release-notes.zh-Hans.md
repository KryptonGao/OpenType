[English](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ko.md)

# OpenType 0.1.6 (7)

本次更新重新设计了 **更新窗口**，并将 **数据保存为 `~/.opentype` 下的可读文件**。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

- **更新窗口**：检查更新时会打开一个小的「软件更新」窗口，显示应用图标、新版本号和更新说明（渲染后的 Markdown，使用界面语言）。可选择「跳过这个版本」「稍后提醒我」或「安装更新」；安装时会切换到单独的进度窗口，显示已下载字节数并可取消。已是最新版本和出错提示改用系统标准提示框，被跳过的版本在后台检查时不再打扰。设置中的更新说明展开项已移除。
- **数据保存在 `~/.opentype`**：全部设置（`settings.json`）、预设与应用规则（`presets.json`）、词典（`dictionary.json`）和历史记录（`history.json`）现在都是 `~/.opentype` 中的纯 JSON 文件，开发版与正式版共用，便于备份或复制到另一台 Mac。旧版本的设置、预设和历史记录会在首次启动时自动迁移一次。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予 **麦克风**、**辅助功能**、**输入监控** 权限。
- 需要自备阿里云百炼或 DeepSeek（语音识别）的 API 密钥，以及所选大语言模型服务的 API 密钥。

## 安装与升级

如果你正在使用 0.1.3 或更高版本，可在应用内更新（设置 → 检查更新）。否则请下载 `OpenType-0.1.6-arm64.dmg`（或 `OpenType-0.1.6-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹，替换旧版本。

此版本使用自签名证书签名，未经 Apple 公证，因此首次启动时会被 Gatekeeper 拦截。可通过以下任一方式放行：

- 在「系统设置 → 隐私与安全性」中点击「仍要打开」；
- 或在终端中运行：

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 只要升级时使用同一个证书签名，你已授予的辅助功能 / 输入监控权限就会保留。

## 下载

| 文件 | 说明 |
|---|---|
| `OpenType-0.1.6-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.6-arm64.zip` | 压缩包，解压后得到 `OpenType.app`（macOS 26.0+，arm64） |
