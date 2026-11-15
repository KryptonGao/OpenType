[English](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ko.md)

# OpenType 0.1.6 (7)

このリリースでは、**アップデートウインドウ**を刷新し、**データを `~/.opentype` 内の読みやすいファイルに保存**するようにしました。

> **動作環境：macOS 26.0+ · Apple シリコン（arm64）**

## 新機能と改善

- **アップデートウインドウ**：アップデートを確認すると、アプリアイコン、新しいバージョン、リリースノート（Markdown を整形して表示、UI の言語）を載せた小さな「ソフトウェア・アップデート」ウインドウが開きます。「このバージョンはスキップ」「あとで通知」「アップデートをインストール」から選べ、インストールを始めると、ダウンロードしたバイト数とキャンセルボタンのある別の進行状況ウインドウに切り替わります。最新である場合やエラーの通知はシステム標準のアラートで表示され、スキップしたバージョンはバックグラウンドの確認では通知されません。設定にあったリリースノートの開閉表示は廃止しました。
- **`~/.opentype` にデータを保存**：すべての設定（`settings.json`）、プリセットとアプリルール（`presets.json`）、辞書（`dictionary.json`）、履歴（`history.json`）を、`~/.opentype` 内の平文の JSON ファイルとして保存します。開発版とリリース版で共有され、バックアップや別の Mac へのコピーも簡単です。以前のバージョンの設定、プリセット、履歴は、初回起動時に一度だけ自動的に移行されます。

## 動作環境

- **macOS 26.0 以降**。
- **Apple シリコン（arm64）専用**です。Intel Mac には対応していません。
- システム設定の「プライバシーとセキュリティ」で、**マイク**、**アクセシビリティ**、**入力監視**の権限を許可してください。
- Alibaba Cloud Bailian または DeepSeek（音声認識）の API キーと、選択した LLM サービスの API キーをご自身で用意してください。

## インストールとアップデート

0.1.3 以降をお使いの場合は、アプリ内でアップデートできます（設定 → アップデートを確認）。それ以外の場合は `OpenType-0.1.6-arm64.dmg`（または `OpenType-0.1.6-arm64.zip`）をダウンロードし、`OpenType.app` を「アプリケーション」フォルダにドラッグして古いバージョンを置き換えてください。

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
| `OpenType-0.1.6-arm64.dmg` | ディスクイメージ。「アプリケーション」へドラッグします（macOS 26.0+、arm64） |
| `OpenType-0.1.6-arm64.zip` | アーカイブ。展開すると `OpenType.app` が得られます（macOS 26.0+、arm64） |
