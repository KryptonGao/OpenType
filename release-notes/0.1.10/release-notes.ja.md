[English](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ko.md)

# OpenType 0.1.10 (11)

今回のアップデートでは、画面の一部を選択してそれについて質問できる**画面に質問**を追加しました。

> **動作環境：macOS 26.0+ · Apple シリコン（arm64）**

## 新機能と改善

- **画面に質問**：グローバルショートカット（デフォルトは ⇧⌘6、「設定 → 画面に質問」で変更可能）を押すと画面が暗くなります。質問したい範囲をドラッグして選択すると、8 つのハンドルでサイズを調整したり、選択範囲を移動したり、選び直したりできます。選択範囲の横に表示されるガラス調のパネルが、その範囲についての質問に Markdown のストリーミングで答えます。質問はテキストでも音声でも入力でき、ショートカットボタンで範囲を Google 画像検索することもできます。回答した質問は履歴にテキストのみで記録され、スクリーンショットは保存されません。
- **Web 検索の設定を共通化**：Web 検索とページ読み取りは「設定 → AI 処理」に移動しました（DeepSeek のみ対応、独立した API キーを使用）。「代わりに話す」と「画面に質問」は既定でこの設定に従い、それぞれオン/オフと積極度を個別に設定することもできます。
- 画面に質問には**画面収録**の権限が必要です。初めて使うときに macOS が許可を求めます。

## 動作環境

- **macOS 26.0 以降**。
- **Apple シリコン（arm64）専用**です。Intel Mac には対応していません。
- システム設定の「プライバシーとセキュリティ」で、**マイク**、**アクセシビリティ**、**入力監視**の権限を許可してください。画面に質問には**画面収録**の権限も必要です。
- Alibaba Cloud Bailian または DeepSeek（音声認識）の API キーと、選択した LLM サービスの API キーをご自身で用意してください。

## インストールとアップデート

0.1.3 以降をお使いの場合は、アプリ内でアップデートできます（設定 → アップデートを確認）。それ以外の場合は `OpenType-0.1.10-arm64.dmg`（または `OpenType-0.1.10-arm64.zip`）をダウンロードし、`OpenType.app` を「アプリケーション」フォルダにドラッグして古いバージョンを置き換えてください。

このビルドは自己署名証明書で署名されており、Apple による公証は受けていないため、初回起動時に Gatekeeper にブロックされます。次のいずれかで許可してください。

- システム設定 → プライバシーとセキュリティで「このまま開く」をクリックする。
- または、ターミナルで次を実行する。

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 同じ証明書で署名されたアップデートであれば、許可済みのアクセシビリティ / 入力監視の権限は保持されます。

## ダウンロード

| ファイル | 説明 |
|---|---|
| `OpenType-0.1.10-arm64.dmg` | ディスクイメージ。「アプリケーション」へドラッグします（macOS 26.0+、arm64） |
| `OpenType-0.1.10-arm64.zip` | アーカイブ。展開すると `OpenType.app` が得られます（macOS 26.0+、arm64） |
