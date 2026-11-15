[English](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ko.md)

# OpenType 0.1.5 (6)

本次更新新增 **预设与按应用规则**，并支持 **锁定麦克风输入设备**。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

- **预设**：原先单一固定的提示词改为可管理的预设，集中在新增的「预设」标签页。每个预设有各自的提示词，并可选择去除句末句号、使用半角标点，以及要启用的词典包。内置预设：日常整理（保持原有行为）、日常沟通、职场邮件、代码与技术提问、Terminal 命令生成；也可以新建自己的预设，或恢复内置预设。
- **应用规则**：每次录音开始时，OpenType 按最前应用的 Bundle ID 匹配，并使用你为该应用指定的预设。应用从「应用程序」文件夹中添加（默认不预置任何应用）。可在菜单栏切换默认预设和按应用自动匹配，也可以在浮层里为单次录音更换预设。
- **Terminal 命令生成**：命令类预设会被压平为单行，只会输入，不会执行。
- **锁定麦克风**：可在「设置 → 语音识别」或菜单栏中指定输入设备（内置、USB、蓝牙、连续互通等）。锁定为内置或外接麦克风后，戴着 AirPods 等蓝牙耳机听歌或开会时，不会被切到低音质通话模式。若所选麦克风是蓝牙设备或已断开，OpenType 会给出提示。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予 **麦克风**、**辅助功能**、**输入监控** 权限。
- 需要自备阿里云百炼或 DeepSeek（语音识别）的 API 密钥，以及所选大语言模型服务的 API 密钥。

## 安装与升级

如果你正在使用 0.1.3 或更高版本，可在应用内更新（设置 → 检查更新）。否则请下载 `OpenType-0.1.5-arm64.dmg`（或 `OpenType-0.1.5-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹，替换旧版本。

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
| `OpenType-0.1.5-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.5-arm64.zip` | 压缩包，解压后得到 `OpenType.app`（macOS 26.0+，arm64） |
