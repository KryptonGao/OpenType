[English](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.ko.md)

# OpenType 0.1.7 (8)

本次更新新增 **书写工具**（可在任意应用中处理文字的悬浮面板）和 **语音改写**（用语音指令修改选中的文字）。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

- **书写工具（⌃⌥W）**：在选中文字（或光标）旁弹出悬浮面板，提供校对（修改处直接标出）、改写、语气调整、摘要 / 要点 / 列表 / 表格、翻译，以及可打字或语音输入的自由指令框。没有选中文字时变为 **撰写**，有两个按钮：生成（纯文本，不带 Markdown 标记）和 **生成 Markdown**（标题、列表、粗体、表格等）。结果可以继续调整、重新生成、复制，并替换或插入回应用中（⌘Z 可撤销）。设置里有独立的快捷键、开关、Profile、模型 ID 和推理强度，以及独立的面板材质（默认磨砂模糊）。可拖动卡片移动面板，它会在鼠标指针旁打开。
- **流式输出**：书写工具的所有回复现在都随模型书写实时显示，并按句渐显。可随时点「停止」；被中断或出错的流式输出绝不会替换你的选中内容，结果完整之前也无法应用或复制。
- **语音改写**：开始听写时若已选中文字，你的语音会被当作修改指令（例如「语气委婉一点」「翻译成日语」）。选中的原文与指令一起交给 LLM，结果替换选中内容；任何一步失败，选中内容都保持原样。Chromium / Electron 应用（Claude、VS Code、Slack、Chrome 等）现在也能正确读取选中内容。
- **翻译时套用当前应用的预设**：新增选项（默认关闭），开启后翻译会遵循当前应用对应的预设：语气与风格、专有名词词库，以及句末句号规则。「Terminal 命令生成」这类命令预设不会用于翻译。适用时，悬浮窗会显示预设胶囊和选择器。
- **预设**：移除了「半角标点」选项，标点交给模型自行选择（拉丁文字用半角，中文用全角）。
- **修复**：书写工具的长结果在自己的区域内滚动，不再冲出圆角卡片；卡片阴影更柔和，格式卡片等大，表格边框对齐，不再出现蓝色焦点框；书写工具使用了自己的图标。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予 **麦克风**、**辅助功能**、**输入监控** 权限。
- 需要自备阿里云百炼或 DeepSeek（语音识别）的 API 密钥，以及所选大语言模型服务的 API 密钥。

## 安装与升级

如果你正在使用 0.1.3 或更高版本，可在应用内更新（设置 → 检查更新）。否则请下载 `OpenType-0.1.7-arm64.dmg`（或 `OpenType-0.1.7-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹，替换旧版本。

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
| `OpenType-0.1.7-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.7-arm64.zip` | 压缩包，解压后得到 `OpenType.app`（macOS 26.0+，arm64） |
