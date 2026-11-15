[English](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ko.md)

# OpenType 0.1.5 (6)

このリリースでは、**プリセットとアプリごとのルール**を追加し、**マイク入力デバイスの固定**に対応しました。

> **動作環境：macOS 26.0+ · Apple シリコン（arm64）**

## 新機能と改善

- **プリセット**：固定だったプロンプトを、新しい「プリセット」タブで管理できるプリセットに置き換えました。各プリセットには専用のプロンプトがあり、文末の句点の削除、半角句読点、オンにする辞書パックを選べます。内蔵プリセットは、日常の整形（従来の動作）、日常のやり取り、ビジネスメール、コードと技術の質問、Terminal コマンド生成です。独自のプリセットを作成したり、内蔵プリセットを復元したりもできます。
- **アプリルール**：録音の開始時に、最前面のアプリを Bundle ID で照合し、そのアプリに割り当てたプリセットを使います。アプリは「アプリケーション」フォルダから追加します（最初は何も登録されていません）。デフォルトのプリセットとアプリによる自動選択はメニューバーから切り替えられ、1 回の録音だけならオーバーレイでプリセットを変更できます。
- **Terminal コマンド生成**：コマンド用のプリセットは 1 行にまとめられ、入力されるだけで実行はされません。
- **マイクの固定**：「設定 → 音声認識」またはメニューバーから入力デバイス（内蔵、USB、Bluetooth、連係カメラなど）を指定できます。内蔵または外部マイクに固定すると、AirPods などの Bluetooth ヘッドホンで音楽を聴いたり会議に参加したりしている間も、低音質の通話モードに切り替わりません。選んだマイクが Bluetooth または未接続の場合は、OpenType が知らせます。

## 動作環境

- **macOS 26.0 以降**。
- **Apple シリコン（arm64）専用**です。Intel Mac には対応していません。
- システム設定の「プライバシーとセキュリティ」で、**マイク**、**アクセシビリティ**、**入力監視**の権限を許可してください。
- Alibaba Cloud Bailian または DeepSeek（音声認識）の API キーと、選択した LLM サービスの API キーをご自身で用意してください。

## インストールとアップデート

0.1.3 以降をお使いの場合は、アプリ内でアップデートできます（設定 → アップデートを確認）。それ以外の場合は `OpenType-0.1.5-arm64.dmg`（または `OpenType-0.1.5-arm64.zip`）をダウンロードし、`OpenType.app` を「アプリケーション」フォルダにドラッグして古いバージョンを置き換えてください。

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
| `OpenType-0.1.5-arm64.dmg` | ディスクイメージ。「アプリケーション」へドラッグします（macOS 26.0+、arm64） |
| `OpenType-0.1.5-arm64.zip` | アーカイブ。展開すると `OpenType.app` が得られます（macOS 26.0+、arm64） |
