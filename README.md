# OpenType

面向 macOS 的全局 AI 语音输入工具。在任意应用的输入框里短按快捷键开始说话、再短按一次结束，随后自动完成语音转写、AI 纠错（去口头禅、补标点），并把文字插入原来的输入位置。

> 平台：macOS 26.0+ · 技术栈：Swift 6 / SwiftUI / AppKit · 许可证：Apache-2.0

## 特性

- **按一下开始、再按一下结束**：全局快捷键，完全自定义——单个按键、组合键、单个修饰键（区分左右，如右 ⌥）或 `fn` 均可。
- **不抢焦点**：悬浮窗为非激活式 `NSPanel`，实时显示音量波形和识别文字（已确认文字 + 浅色的未稳定部分）。
- **ASR**：`AVAudioEngine` 采集，16 kHz / 单声道 / PCM16。可选阿里云百炼 `qwen3-asr-flash-realtime`（实时流式）或 DeepSeek（录完后整段上传）。
- **ASR 与 LLM 解耦**：内置 OpenAI Responses、OpenAI Chat Completions、Anthropic Messages 三种协议适配器，兼容第三方 OpenAI 兼容服务；支持多 Profile、三档处理等级（原始 / 标准 / 深度整理）。
- **失败不丢字**：LLM 失败或超时可自动回退为 ASR 原文；ASR 断线时保留已识别内容供复制；`Esc` 随时取消，取消时不会插入任何文字。
- **三级插入**：Accessibility 直写 → 模拟粘贴（自动备份并恢复剪贴板）→ 悬浮窗手动复制。不会向密码框、安全输入模式或已切换的应用写入，也不会自动回车或提交。
- **隐私优先**：API Key 只存 macOS Keychain；默认不保存音频和识别记录；日志不含语音与文字内容。

## 工作流程

```
idle → connecting → recording → finalizing → processing → inserting → idle
```

1. 短按快捷键开始：记录当前焦点应用与输入控件，弹出悬浮窗并开始采集音频，流式发送到 ASR。
2. 再短按一次结束：停止采集，发送剩余音频和 `session.finish`，等待最终转写，再交给 LLM 整理（原始模式跳过）。
3. 把结果插入原输入控件，悬浮窗短暂提示后关闭。

每次会话都有唯一的 Session ID，所有异步回调都会先校验；处理中不允许开始新会话。

## 安装与首次配置

### 构建

需要 Xcode（支持 macOS 26 SDK）。

```bash
git clone https://github.com/KryptonGao/OpenType.git
cd OpenType
open OpenType.xcodeproj
```

在 Xcode 里选择你自己的签名团队后直接运行；或用命令行构建：

```bash
xcodebuild -project OpenType.xcodeproj -scheme OpenType -configuration Release -destination 'platform=macOS' build
```

> 建议使用稳定的开发者证书签名。ad-hoc 签名每次重新构建身份都会变化，系统会让「辅助功能 / 输入监控」授权失效。

### 授权

首次启动后在「设置 → 隐私与权限」里授权，并在系统设置的「隐私与安全性」中打开 OpenType：

| 权限 | 用途 |
|---|---|
| 麦克风 | 采集语音（首次录音时会弹窗） |
| 辅助功能 | 向其他应用的输入框写入文本、模拟粘贴 |
| 输入监控 | 监听全局快捷键 |

授权后快捷键会自动生效。如果开关已打开但仍显示未授权，点「重启 OpenType」；仍无效时，在系统设置列表里删除 OpenType 再重新添加。

### 配置服务

- **语音识别**（设置 → 语音识别）：先选择服务商。
  - 阿里云百炼（实时流式）：选择区域（北京 / 新加坡），填写 Workspace ID 与 API Key，可点「测试连接」。也支持自定义 `wss://` 地址。
  - DeepSeek（整段识别）：只需填写 API Key。该接口不支持流式，录音期间没有实时文字，结束后上传整段 WAV 并返回结果；单次请求最长 120 秒，更长的录音自动分段识别。
- **AI 处理**（设置 → AI 处理）：新建 Profile，选择 API 格式，填写 Base URL、Model ID 和 API Key，可点「测试连接」。Base URL 只允许 `https`，末尾的 `/v1`、`/responses` 等会被规范化，不会重复拼接。

## 使用

- 在任意输入框短按快捷键开始说话，再短按一次结束，随后自动整理并插入。默认快捷键是 `⌃⌥ Space`，可在「设置 → 通用」里点击录入框直接按下新的按键。
- 说话或处理过程中按 `Esc` 取消。
- 无法自动插入时（密码框、焦点已变化等），结果会显示在悬浮窗里，点「复制文本」即可。
- 菜单栏图标里也可以手动开始 / 结束语音输入、暂停快捷键、查看权限状态。

关于快捷键的几点说明：

- 仅修饰键的快捷键（如 fn、右 ⌥）在「松开」时才触发一次，且按住期间没有按其他键或鼠标，避免和 `⌘C`、`⌥` + 点击这类操作冲突；轻点一下即可。
- 不带修饰键的普通字符键会被快捷键独占，建议搭配修饰键；`F1–F20` 不受影响。
- `Esc` 保留为取消键。
- 想用 `fn` 的话，请先到「系统设置 → 键盘」把单按 fn 的系统动作改成「无操作」。

## 隐私与安全

- 录音会发送到你选择的语音识别服务（阿里云百炼实时流式，或 DeepSeek 录完后整段上传）；转写文本会发送到你配置的 LLM 服务。除此之外没有任何其他网络请求。
- API Key 仅保存在 Keychain，界面只显示「已保存」，不会读回；不会写入 `UserDefaults`、日志或错误提示。
- 只接受校验证书的 HTTPS / WSS；Workspace ID 经过格式校验，密钥只会发往由它生成的阿里云域名或你明确填写的自定义 `wss://` 地址。
- 默认不落盘原始音频和识别记录。诊断日志默认关闭，开启后也只记录各阶段耗时。

## 项目结构

```
OpenType/
├── App/            应用入口、AppDelegate、全局对象
├── Core/           会话状态机与协调器、转写聚合器
├── Services/
│   ├── Audio/      AVAudioEngine 采集、重采样与分块
│   ├── ASR/        百炼实时识别 WebSocket 客户端、DeepSeek 整段识别客户端
│   ├── LLM/        三种协议适配器、Prompt、错误映射
│   ├── Hotkey/     CGEventTap 全局快捷键与快捷键配置
│   ├── Insertion/  三级文本插入
│   └── Permissions/ 权限检测与引导
├── Storage/        SettingsStore（UserDefaults）、CredentialStore（Keychain）
├── UI/             菜单栏、悬浮窗、设置窗口
└── Util/           诊断日志
OpenTypeTests/      单元测试
```

## 测试

```bash
xcodebuild -project OpenType.xcodeproj -scheme OpenType -destination 'platform=macOS' test
```

测试覆盖转写聚合、ASR 配置与 `session.update` 内容、三种 LLM 协议的请求与响应解析及错误映射、快捷键状态机、设置存储，以及用假音频 / ASR / LLM / 插入组件驱动的端到端会话流程（成功、回退、取消、各类失败）。

## 路线图

- 切换式录音（按一次开始、再按一次结束）
- 自定义词典 / 热词、多 Prompt 预设
- 可选的本地历史记录、应用级规则
- 更多语音模型 / 本地 ASR、多语言界面
- 全场景兼容性验证（Safari / Chrome / VS Code / Electron / IM / 全屏 / 多屏 / 输入法切换）与 Developer ID 签名、公证

不在范围内：账号与云同步、订阅计费、自建推理服务、非 macOS 平台、多人会议与说话人分离。

产品需求详见 [OpenType PRD.md](OpenType%20PRD.md)。

## 许可证

[Apache License 2.0](LICENSE)
