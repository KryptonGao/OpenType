[English](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ko.md)

# OpenType 0.1.3 (4)

今回のアップデートで「アプリ内アップデート」が加わりました。OpenType が GitHub Release を自分で確認し、新バージョンの DMG をダウンロード・検証してインストールまで行うので、アプリを手動で置き換える必要はありません。

> **動作環境：macOS 26.0 以降 · Apple シリコン（arm64）**

## 新機能と改善

- **アプリ内アップデート**：設定から GitHub Release の新バージョンを確認でき、見つかったら DMG のダウンロード、検証、インストールをアプリ内で実行できます。
- **自動確認と自動インストール**：アップデートを自動で確認するかどうか、新バージョンが見つかったら自動でインストールするかどうかを選べます。
- **メニューバーの通知**：メニューバーのメニューにアップデートの状態と更新の入口が表示されます。
- アップデート関連のローカライズ文字列（简体中文、繁體中文、English、日本語、한국어）とユニットテストを追加しました。

## 動作環境

- **macOS 26.0 以降**。
- **Apple シリコン（arm64）のみ**対応です。Intel Mac には対応していません。
- システム設定の「プライバシーとセキュリティ」で **マイク**、**アクセシビリティ**、**入力監視** の権限を許可する必要があります。
- アリババクラウド百煉（Bailian）または DeepSeek の API キー（ASR）と、選択した LLM サービスの API キーをご自身で用意してください。

## インストールとアップデート

`OpenType-0.1.3-arm64.dmg`（または `OpenType-0.1.3-arm64.zip`）をダウンロードし、`OpenType.app` を「アプリケーション」フォルダにドラッグして古いバージョンを置き換えてください。0.1.3 以降は、以降のバージョンをアプリ内で更新できます。

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
| `OpenType-0.1.3-arm64.dmg` | ディスクイメージ。「アプリケーション」にドラッグするだけ（macOS 26.0+、arm64） |
| `OpenType-0.1.3-arm64.zip` | zip アーカイブ。展開すると `OpenType.app` が得られます（macOS 26.0+、arm64） |
