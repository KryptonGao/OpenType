[English](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.7/release-notes/0.1.7/release-notes.ko.md)

# OpenType 0.1.7 (8)

本次更新新增 **書寫工具**（可在任何應用程式中處理文字的懸浮面板）和 **語音改寫**（用語音指令修改選取的文字）。

> **系統需求：macOS 26.0+ · Apple 晶片（arm64）**

## 新增與改進

- **書寫工具（⌃⌥W）**：在選取文字（或游標）旁彈出懸浮面板，提供校對（修改處直接標出）、改寫、語氣調整、摘要 / 重點 / 列表 / 表格、翻譯，以及可打字或語音輸入的自由指令框。沒有選取文字時變為 **撰寫**，有兩個按鈕：生成（純文字，不帶 Markdown 標記）和 **生成 Markdown**（標題、列表、粗體、表格等）。結果可以繼續調整、重新生成、複製，並取代或插入回應用程式中（⌘Z 可還原）。設定中有獨立的快速鍵、開關、Profile、模型 ID 和推理強度，以及獨立的面板材質（預設為霧面模糊）。可拖曳卡片移動面板，它會在滑鼠游標旁開啟。
- **串流輸出**：書寫工具的所有回覆現在都隨模型書寫即時顯示，並按句漸顯。可隨時按「停止」；被中斷或出錯的串流輸出絕不會取代你選取的內容，結果完整之前也無法套用或複製。
- **語音改寫**：開始聽寫時若已選取文字，你的語音會被當作修改指令（例如「語氣委婉一點」「翻譯成日文」）。選取的原文與指令一起交給 LLM，結果取代選取內容；任何一步失敗，選取內容都保持原樣。Chromium / Electron 應用程式（Claude、VS Code、Slack、Chrome 等）現在也能正確讀取選取內容。
- **翻譯時套用目前 App 的預設**：新增選項（預設關閉），開啟後翻譯會遵循目前 App 對應的預設：語氣與風格、專有名詞詞庫，以及句末句號規則。「Terminal 命令生成」這類命令預設不會用於翻譯。適用時，懸浮視窗會顯示預設膠囊和選擇器。
- **預設**：移除了「半形標點」選項，標點交給模型自行選擇（拉丁文字用半形，中文用全形）。
- **修復**：書寫工具的長結果在自己的區域內捲動，不再衝出圓角卡片；卡片陰影更柔和，格式卡片等大，表格邊框對齊，不再出現藍色焦點框；書寫工具使用了自己的圖示。

## 系統需求

- **macOS 26.0 及以上**。
- **僅支援 Apple 晶片（arm64）**，不支援 Intel Mac。
- 需要在系統設定的「隱私權與安全性」中授予 **麥克風**、**輔助使用**、**輸入監控** 權限。
- 需要自備阿里雲百煉或 DeepSeek（語音辨識）的 API 金鑰，以及所選大型語言模型服務的 API 金鑰。

## 安裝與升級

如果你正在使用 0.1.3 或更新版本，可在應用程式內更新（設定 → 檢查更新）。否則請下載 `OpenType-0.1.7-arm64.dmg`（或 `OpenType-0.1.7-arm64.zip`），將 `OpenType.app` 拖入「應用程式」檔案夾，取代舊版本。

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
| `OpenType-0.1.7-arm64.dmg` | 磁碟映像，拖入「應用程式」即可（macOS 26.0+，arm64） |
| `OpenType-0.1.7-arm64.zip` | 壓縮檔，解壓縮後得到 `OpenType.app`（macOS 26.0+，arm64） |
