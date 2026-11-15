[English](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ko.md)

# OpenType 0.1.5 (6)

本次更新新增 **預設與依應用程式規則**，並支援 **鎖定麥克風輸入裝置**。

> **系統需求：macOS 26.0+ · Apple 晶片（arm64）**

## 新增與改進

- **預設**：原本單一固定的提示詞改為可管理的預設，集中在新增的「預設」分頁。每個預設有各自的提示詞，並可選擇移除句末句號、使用半形標點，以及要啟用的詞典包。內建預設：日常整理（維持原有行為）、日常溝通、職場郵件、程式碼與技術提問、Terminal 指令產生；也可以新增自己的預設，或還原內建預設。
- **應用程式規則**：每次錄音開始時，OpenType 依最前方應用程式的 Bundle ID 配對，並使用你為該應用程式指定的預設。應用程式從「應用程式」檔案夾中加入（預設不預先加入任何應用程式）。可在選單列切換預設值和依應用程式自動配對，也可以在浮層中為單次錄音更換預設。
- **Terminal 指令產生**：指令類預設會被壓平為單行，只會輸入，不會執行。
- **鎖定麥克風**：可在「設定 → 語音辨識」或選單列中指定輸入裝置（內建、USB、藍牙、連續互通等）。鎖定為內建或外接麥克風後，戴著 AirPods 等藍牙耳機聽歌或開會時，不會被切換到低音質通話模式。若所選麥克風是藍牙裝置或已中斷連線，OpenType 會顯示提示。

## 系統需求

- **macOS 26.0 及以上**。
- **僅支援 Apple 晶片（arm64）**，不支援 Intel Mac。
- 需要在系統設定的「隱私權與安全性」中授予 **麥克風**、**輔助使用**、**輸入監控** 權限。
- 需要自備阿里雲百煉或 DeepSeek（語音辨識）的 API 金鑰，以及所選大型語言模型服務的 API 金鑰。

## 安裝與升級

如果你正在使用 0.1.3 或更新版本，可在應用程式內更新（設定 → 檢查更新）。否則請下載 `OpenType-0.1.5-arm64.dmg`（或 `OpenType-0.1.5-arm64.zip`），將 `OpenType.app` 拖入「應用程式」檔案夾，取代舊版本。

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
| `OpenType-0.1.5-arm64.dmg` | 磁碟映像，拖入「應用程式」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.5-arm64.zip` | 壓縮檔，解壓縮後得到 `OpenType.app`（macOS 26.0+，arm64） |
