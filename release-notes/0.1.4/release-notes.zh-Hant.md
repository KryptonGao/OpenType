[English](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ko.md)

# OpenType 0.1.4 (5)

本次更新重新設計了主視窗，採用 **原生側邊欄版面**，讓 OpenType 用起來更像一款標準的 macOS 應用程式。

> **系統需求：macOS 26.0+ · Apple 晶片（arm64）**

## 新增與改進

- **原生側邊欄版面**：主視窗改為側邊欄，包含「首頁」「歷史」「詞典」，其後是「設定」分區，收納六個設定頁面；設定分頁內的分段切換器已移除。
- **首頁**：頂部新增快捷鍵狀態卡片，統計資料合併為一列帶邊框的群組，時間範圍選擇器移到視窗工具列。
- **歷史與詞典**：使用原生搜尋欄和工具列按鈕，開關控制項更小，詞典包以群組表單呈現。
- **選單列與浮層**：選單列選單加入 SF Symbols 圖示和狀態圖示；浮層卡片圓角更大，並增加狀態圖示。

## 系統需求

- **macOS 26.0 及以上**。
- **僅支援 Apple 晶片（arm64）**，不支援 Intel Mac。
- 需要在系統設定的「隱私權與安全性」中授予 **麥克風**、**輔助使用**、**輸入監控** 權限。
- 需要自備阿里雲百煉或 DeepSeek 的 API Key（ASR），以及你所選 LLM 服務的 API Key。

## 安裝與升級

如果你正在使用 0.1.3 或更新版本，可直接在應用程式內更新（在設定中檢查更新）。否則請下載 `OpenType-0.1.4-arm64.dmg`（或 `OpenType-0.1.4-arm64.zip`），將 `OpenType.app` 拖入「應用程式」資料夾覆蓋舊版本。

本版本使用自簽名憑證簽名，未經 Apple 公證，首次開啟會被 Gatekeeper 攔截。請任選一種方式放行：

- 在「系統設定 → 隱私權與安全性」中點按「強制打開」；
- 或在終端機執行：

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 升級只要仍使用同一張憑證簽名，輔助使用 / 輸入監控授權會保留。

## 下載

| 檔案 | 說明 |
|---|---|
| `OpenType-0.1.4-arm64.dmg` | 磁碟映像，拖入「應用程式」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.4-arm64.zip` | 壓縮檔，解壓縮即得 `OpenType.app`（macOS 26.0+，arm64） |
