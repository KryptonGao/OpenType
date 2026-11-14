[English](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ko.md)

# OpenType 0.1.4 (5)

本次更新重新设计了主窗口，采用 **原生侧边栏布局**，让 OpenType 用起来更像一款标准的 macOS 应用。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

- **原生侧边栏布局**：主窗口改为侧边栏，包含「首页」「历史」「词典」，其后是「设置」分区，收纳六个设置页面；设置标签页内的分段切换器已移除。
- **首页**：顶部新增快捷键状态卡片，统计数据合并为一行带边框的分组，时间范围选择器移到窗口工具栏。
- **历史与词典**：使用原生搜索框和工具栏按钮，开关控件更小，词典包以分组表单呈现。
- **菜单栏与浮层**：菜单栏菜单加入 SF Symbols 图标和状态图标；浮层卡片圆角更大，并增加状态图标。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予 **麦克风**、**辅助功能**、**输入监控** 权限。
- 需要自备阿里云百炼或 DeepSeek 的 API Key（ASR），以及你所选 LLM 服务的 API Key。

## 安装与升级

如果你正在使用 0.1.3 或更高版本，可直接在应用内更新（设置中检查更新）。否则请下载 `OpenType-0.1.4-arm64.dmg`（或 `OpenType-0.1.4-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹覆盖旧版本。

本版本使用自签名证书签名，未经 Apple 公证，首次打开会被 Gatekeeper 拦截。请任选一种方式放行：

- 在「系统设置 → 隐私与安全性」中点击「仍要打开」；
- 或在终端执行：

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 升级只要仍使用同一张证书签名，辅助功能 / 输入监控授权会保留。

## 下载

| 文件 | 说明 |
|---|---|
| `OpenType-0.1.4-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.4-arm64.zip` | 压缩包，解压即得 `OpenType.app`（macOS 26.0+，arm64） |
