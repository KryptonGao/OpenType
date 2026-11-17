[English](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ko.md)

# OpenType 0.1.10 (11)

本次更新新增**屏幕提问**：框选屏幕上的一块区域，直接对它提问。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

- **屏幕提问**：按下全局快捷键（默认 ⇧⌘6，可在「设置 → 屏幕提问」中修改），屏幕会变暗。拖出一个选框圈住想问的区域，之后仍可通过 8 个控制点调整大小、移动选框或重新框选。选框旁边的玻璃面板会就该区域回答你的问题，回复以 Markdown 流式显示。可以打字或语音提问，也可以用快捷按钮在 Google 图片中搜索该区域。回答过的问题会以纯文字记入历史记录，不会保存截图。
- **联网搜索设置改为共用**：联网搜索与网页读取移到「设置 → AI 处理」（仅支持 DeepSeek，使用独立的 API Key）。「帮我说」和「屏幕提问」默认沿用这一设置，也可以各自单独设置开关和积极度。
- 屏幕提问需要**屏幕录制**权限，首次使用时 macOS 会请求授权。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予**麦克风**、**辅助功能**、**输入监控**权限；使用屏幕提问还需要**屏幕录制**权限。
- 需要自备阿里云百炼或 DeepSeek（语音识别）的 API 密钥，以及所选大语言模型服务的 API 密钥。

## 安装与升级

如果你正在使用 0.1.3 或更高版本，可在应用内更新（设置 → 检查更新）。否则请下载 `OpenType-0.1.10-arm64.dmg`（或 `OpenType-0.1.10-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹，替换旧版本。

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
| `OpenType-0.1.10-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.10-arm64.zip` | 压缩包，解压后得到 `OpenType.app`（macOS 26.0+，arm64） |
