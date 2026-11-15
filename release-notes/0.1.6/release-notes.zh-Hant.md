[English](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ko.md)

# OpenType 0.1.6 (7)

本次更新重新設計了 **更新視窗**，並將 **資料儲存為 `~/.opentype` 下的可讀檔案**。

> **系統需求：macOS 26.0+ · Apple 晶片（arm64）**

## 新增與改進

- **更新視窗**：檢查更新時會開啟一個小的「軟體更新」視窗，顯示應用程式圖像、新版本號和更新說明（渲染後的 Markdown，使用介面語言）。可選擇「跳過此版本」「暫緩提醒」或「安裝更新」；安裝時會切換到獨立的進度視窗，顯示已下載位元組數並可取消。已是最新版本與錯誤提示改用系統標準提示框，被跳過的版本在背景檢查時不再打擾。設定中的更新說明展開項已移除。
- **資料儲存在 `~/.opentype`**：全部設定（`settings.json`）、預設與應用程式規則（`presets.json`）、詞典（`dictionary.json`）和歷史記錄（`history.json`）現在都是 `~/.opentype` 中的純 JSON 檔案，開發版與正式版共用，方便備份或複製到另一台 Mac。舊版本的設定、預設和歷史記錄會在首次啟動時自動遷移一次。

## 系統需求

- **macOS 26.0 及以上**。
- **僅支援 Apple 晶片（arm64）**，不支援 Intel Mac。
- 需要在系統設定的「隱私權與安全性」中授予 **麥克風**、**輔助使用**、**輸入監控** 權限。
- 需要自備阿里雲百煉或 DeepSeek（語音辨識）的 API 金鑰，以及所選大型語言模型服務的 API 金鑰。

## 安裝與升級

如果你正在使用 0.1.3 或更新版本，可在應用程式內更新（設定 → 檢查更新）。否則請下載 `OpenType-0.1.6-arm64.dmg`（或 `OpenType-0.1.6-arm64.zip`），將 `OpenType.app` 拖入「應用程式」檔案夾，取代舊版本。

此版本使用自簽憑證簽署，未經 Apple 公證，因此首次啟動時會被 Gatekeeper 攔截。可透過以下任一方式放行：

- 在「系統設定 → 隱私權與安全性」中點按「仍要打開」；
- 或在終端機中執行：

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 只要升級時使用同一個憑證簽署，你已授予的輔助使用 / 輸入監控權限就會保留。

## 下載

| 檔案 | 說明 |
|---|---|
| `OpenType-0.1.6-arm64.dmg` | 磁碟映像，拖入「應用程式」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.6-arm64.zip` | 壓縮檔，解壓縮後得到 `OpenType.app`（macOS 26.0+，arm64） |
