[English](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.9/release-notes/0.1.9/release-notes.ko.md)

# OpenType 0.1.9 (10)

本次更新让模型的回复以 **Markdown** 渲染，支持表格、代码块和 LaTeX 公式。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

- **Markdown 回复**：书写工具的结果（包括流式输出过程中）、听写浮层中的待确认文字，以及历史记录详情中的结果，现在都会正确渲染 Markdown：标题、列表、表格、代码块和 LaTeX 公式，不再显示原始符号。
- **更新窗口中的更新说明**改用同一个渲染器，显示更加可靠。
- **书写工具**：输入框中新增 Apple Intelligence 图标。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予 **麦克风**、**辅助功能**、**输入监控** 权限。
- 需要自备阿里云百炼或 DeepSeek（语音识别）的 API 密钥，以及所选大语言模型服务的 API 密钥。

## 安装与升级

如果你正在使用 0.1.3 或更高版本，可在应用内更新（设置 → 检查更新）。否则请下载 `OpenType-0.1.9-arm64.dmg`（或 `OpenType-0.1.9-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹，替换旧版本。

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
| `OpenType-0.1.9-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.9-arm64.zip` | 压缩包，解压后得到 `OpenType.app`（macOS 26.0+，arm64） |
