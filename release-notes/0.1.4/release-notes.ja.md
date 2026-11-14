[English](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ko.md)

# OpenType 0.1.4 (5)

今回のアップデートでメインウインドウを刷新し、**ネイティブなサイドバーレイアウト**を採用しました。OpenType がより標準的な macOS アプリらしい見た目と操作感になります。

> **動作環境：macOS 26.0 以降 · Apple シリコン（arm64）**

## 新機能と改善

- **ネイティブなサイドバーレイアウト**：メインウインドウがサイドバー形式になり、「ホーム」「履歴」「辞書」に続いて、6 つの設定ページをまとめた「設定」セクションが並びます。設定タブ内のセグメント切り替えは廃止されました。
- **ホーム**：上部にショートカットの状態カードを追加し、統計は枠付きの 1 行にまとめ、期間の選択はウインドウのツールバーに移動しました。
- **履歴と辞書**：ネイティブの検索フィールドとツールバー項目を使用し、スイッチを小型化し、辞書パックはグループ化されたフォームで表示します。
- **メニューバーとオーバーレイ**：メニューバーのメニューに SF Symbols と状態アイコンを追加し、オーバーレイカードは角丸を大きくして状態アイコンを表示します。

## 動作環境

- **macOS 26.0 以降**。
- **Apple シリコン（arm64）のみ**対応です。Intel Mac には対応していません。
- システム設定の「プライバシーとセキュリティ」で **マイク**、**アクセシビリティ**、**入力監視** の権限を許可する必要があります。
- アリババクラウド百煉（Bailian）または DeepSeek の API キー（ASR）と、選択した LLM サービスの API キーをご自身で用意してください。

## インストールとアップデート

0.1.3 以降をお使いの場合は、アプリ内でアップデートできます（設定でアップデートを確認）。それ以外の場合は `OpenType-0.1.4-arm64.dmg`（または `OpenType-0.1.4-arm64.zip`）をダウンロードし、`OpenType.app` を「アプリケーション」フォルダにドラッグして古いバージョンを置き換えてください。

このバージョンは自己署名証明書で署名されており、Apple の公証を受けていないため、初回起動時に Gatekeeper にブロックされます。次のいずれかの方法で許可してください。

- 「システム設定 → プライバシーとセキュリティ」で「このまま開く」をクリックする。
- または、ターミナルで次を実行する。

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 同じ証明書で署名されている限り、アップデート後もアクセシビリティ / 入力監視の許可は維持されます。

## ダウンロード

| ファイル | 説明 |
|---|---|
| `OpenType-0.1.4-arm64.dmg` | ディスクイメージ。「アプリケーション」にドラッグするだけ（macOS 26.0+、arm64） |
| `OpenType-0.1.4-arm64.zip` | zip アーカイブ。展開すると `OpenType.app` が得られます（macOS 26.0+、arm64） |
