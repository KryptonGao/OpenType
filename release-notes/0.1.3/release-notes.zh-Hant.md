[English](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ko.md)

# OpenType 0.1.3 (4)

本次更新新增「應用程式內更新」：OpenType 可以自行檢查 GitHub Release，下載並驗證新版本的 DMG 後完成安裝，不必再手動替換應用程式。

> **系統需求：macOS 26.0+ · Apple 晶片（arm64）**

## 新增與改進

- **應用程式內更新**：在設定中檢查 GitHub Release 上的新版本，發現更新後可直接下載 DMG、驗證並安裝。
- **自動檢查與自動安裝**：可選擇自動檢查更新，也可選擇在發現新版本後自動安裝。
- **選單列提示**：選單列選單中會顯示更新狀態與入口。
- 新增更新相關的在地化文案（简体中文、繁體中文、English、日本語、한국어）及單元測試。

## 系統需求

- **macOS 26.0 及以上**。
- **僅支援 Apple 晶片（arm64）**，不支援 Intel Mac。
- 需要在系統設定的「隱私權與安全性」中授予 **麥克風**、**輔助使用**、**輸入監控** 權限。
- 需要自備阿里雲百煉或 DeepSeek 的 API Key（ASR），以及你所選 LLM 服務的 API Key。

## 安裝與升級

下載 `OpenType-0.1.3-arm64.dmg`（或 `OpenType-0.1.3-arm64.zip`），將 `OpenType.app` 拖入「應用程式」資料夾覆蓋舊版本。從 0.1.3 起，後續版本可直接在應用程式內更新。

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
| `OpenType-0.1.3-arm64.dmg` | 磁碟映像，拖入「應用程式」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.3-arm64.zip` | 壓縮檔，解壓縮即得 `OpenType.app`（macOS 26.0+，arm64） |
