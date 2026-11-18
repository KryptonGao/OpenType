[English](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.ko.md)

# OpenType 0.1.11 (12)

屏幕提问现已支持用 Bing 搜索图片。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

在「**设置 → 屏幕提问 → 图片搜索引擎**」中选择 **Google** 或 **Bing**，默认使用 Google。点击选区旁的「**图片搜索**」，默认浏览器会将选区图片上传到所选引擎。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予**麦克风**、**辅助功能**、**输入监控**权限；使用屏幕提问还需要**屏幕录制**权限。
- 需要自备阿里云百炼或 DeepSeek（语音识别）的 API 密钥，以及所选大语言模型服务的 API 密钥。

## 安装与升级

如果你正在使用 0.1.3 或更高版本，可在应用内更新（设置 → 检查更新）。否则请下载 `OpenType-0.1.11-arm64.dmg`（或 `OpenType-0.1.11-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹，替换旧版本。

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
| `OpenType-0.1.11-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.11-arm64.zip` | 压缩包，解压后得到 `OpenType.app`（macOS 26.0+，arm64） |
