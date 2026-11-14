# OpenType 0.1.3 (4)

本次更新新增「应用内更新」：OpenType 可以自行检查 GitHub Release，下载并校验新版本的 DMG 后完成安装，不必再手动替换应用。

> **系统要求：macOS 26.0+ · Apple 芯片（arm64）**

## 新增与改进

- **应用内更新**：在设置中检查 GitHub Release 上的新版本，发现更新后可直接下载 DMG、校验并安装。
- **自动检查与自动安装**：可选择自动检查更新，也可选择在发现新版本后自动安装。
- **菜单栏提示**：菜单栏菜单中会显示更新状态与入口。
- 新增更新相关的本地化文案（简体中文、繁體中文、English、日本語、한국어）及单元测试。

## 系统要求

- **macOS 26.0 及以上**。
- **仅支持 Apple 芯片（arm64）**，不支持 Intel Mac。
- 需要在系统设置的「隐私与安全性」中授予 **麦克风**、**辅助功能**、**输入监控** 权限。
- 需要自备阿里云百炼或 DeepSeek 的 API Key（ASR），以及你所选 LLM 服务的 API Key。

## 安装与升级

下载 `OpenType-0.1.3-arm64.dmg`（或 `OpenType-0.1.3-arm64.zip`），将 `OpenType.app` 拖入「应用程序」文件夹覆盖旧版本。从 0.1.3 起，后续版本可直接在应用内更新。

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
| `OpenType-0.1.3-arm64.dmg` | 磁盘映像，拖入「应用程序」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.3-arm64.zip` | 压缩包，解压即得 `OpenType.app`（macOS 26.0+，arm64） |
