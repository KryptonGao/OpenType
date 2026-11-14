# AGENTS.md

## 提交与分支

用户没有明确要求提交 PR 时，改动默认直接提交到 `main` 分支（不要新建分支或开 PR）。只有用户明确说“提交 PR / 开 PR”时，才走分支 + PR 流程。

## 完成改动后打包新的 .app

每次完成代码改动（且构建/测试通过）后，必须打包一个新的 Release 版 `.app` 供用户测试，除非用户明确说“不要打包”。

```bash
xcodebuild build -project OpenType.xcodeproj -scheme OpenType -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
&& rm -rf build/OpenType.app \
&& cp -R build/DerivedData/Build/Products/Release/OpenType.app build/OpenType.app \
&& codesign --force --sign "OpenType Self-Signed" \
     --options runtime --entitlements OpenType/OpenType.entitlements build/OpenType.app
```

- 产物路径：`build/OpenType.app`（`build/` 已在 `.gitignore` 中，不会被提交）。
- 完成后在回复里告知用户 .app 的路径。
- 测试命令：`xcodebuild test -project OpenType.xcodeproj -scheme OpenType -destination 'platform=macOS'`。

### 必须用固定证书重签名（重要）

工程默认是 ad-hoc 签名（`CODE_SIGN_IDENTITY = "-"`），其 designated requirement 是代码哈希（cdhash），**每次构建都会变**。
macOS 的「辅助功能 / 输入监控」授权是按签名身份记录的，所以 ad-hoc 构建后授权会失效：系统设置里开关仍是开的，但应用实际没有权限（全局快捷键不生效）。

因此打包后必须用固定的自签名证书 `OpenType Self-Signed` 重签名（上面命令的最后一步）。这样 designated requirement 变为“bundle id + 证书”，
重新构建后授权依然有效。打包完成后可用 `codesign -d -r- build/OpenType.app` 确认不再是 `cdhash`。

- 该证书是本机自签名的代码签名证书（有效期 10 年），在登录钥匙串中；备份为 `~/OpenType-Signing/OpenType-Signing.p12`（不要提交到仓库）。
- 对外分发也用同一张证书签名，这样用户更新后授权同样保留。自签名无法通过 Gatekeeper，用户首次打开需在「系统设置 → 隐私与安全性」点「仍要打开」，
  或执行 `xattr -dr com.apple.quarantine /Applications/OpenType.app`。
- 证书丢失或更换后，签名身份会变，所有用户和本机都需要重新授权辅助功能 / 输入监控。
- 若以后要消除首次打开的警告，需加入 Apple Developer Program，改用 Developer ID Application 证书签名并用 `notarytool` 公证。
