[English](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.11/release-notes/0.1.11/release-notes.ko.md)

# OpenType 0.1.11 (12)

螢幕提問現在支援使用 Bing 搜尋圖片。

> **系統需求：macOS 26.0+ · Apple 晶片（arm64）**

## 新增與改進

在「**設定 → 螢幕提問 → 圖片搜尋引擎**」中選擇 **Google** 或 **Bing**，預設使用 Google。點擊選取範圍旁的「**圖片搜尋**」，預設瀏覽器會將選取範圍的圖片上傳至所選引擎。

## 系統需求

- **macOS 26.0 及以上**。
- **僅支援 Apple 晶片（arm64）**，不支援 Intel Mac。
- 需要在系統設定的「隱私權與安全性」中授予 **麥克風**、**輔助使用**、**輸入監控** 權限；使用螢幕提問還需要 **螢幕錄製** 權限。
- 需要自備阿里雲百煉或 DeepSeek（語音辨識）的 API 金鑰，以及所選大型語言模型服務的 API 金鑰。

## 安裝與升級

如果你正在使用 0.1.3 或更新版本，可在應用程式內更新（設定 → 檢查更新）。否則請下載 `OpenType-0.1.11-arm64.dmg`（或 `OpenType-0.1.11-arm64.zip`），將 `OpenType.app` 拖入「應用程式」檔案夾，取代舊版本。

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
| `OpenType-0.1.11-arm64.dmg` | 磁碟映像，拖入「應用程式」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.11-arm64.zip` | 壓縮檔，解壓縮後得到 `OpenType.app`（macOS 26.0+，arm64） |
