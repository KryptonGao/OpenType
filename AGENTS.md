# AGENTS.md

## 完成改动后打包新的 .app

每次完成代码改动（且构建/测试通过）后，必须打包一个新的 Release 版 `.app` 供用户测试，除非用户明确说“不要打包”。

```bash
xcodebuild build -project OpenType.xcodeproj -scheme OpenType -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
&& rm -rf build/OpenType.app \
&& cp -R build/DerivedData/Build/Products/Release/OpenType.app build/OpenType.app \
&& codesign --force --sign "$(security find-identity -v -p codesigning | awk '/Apple Development/{print $2; exit}')" \
     --options runtime --entitlements OpenType/OpenType.entitlements build/OpenType.app
```

- 产物路径：`build/OpenType.app`（`build/` 已在 `.gitignore` 中，不会被提交）。
- 完成后在回复里告知用户 .app 的路径。
- 测试命令：`xcodebuild test -project OpenType.xcodeproj -scheme OpenType -destination 'platform=macOS'`。

### 必须用固定证书重签名（重要）

工程默认是 ad-hoc 签名（`CODE_SIGN_IDENTITY = "-"`），其 designated requirement 是代码哈希（cdhash），**每次构建都会变**。
macOS 的「辅助功能 / 输入监控」授权是按签名身份记录的，所以 ad-hoc 构建后授权会失效：系统设置里开关仍是开的，但应用实际没有权限（全局快捷键不生效）。

因此打包后必须用本机的 Apple Development 证书重签名（上面命令的最后一步）。这样 designated requirement 变为“bundle id + 证书”，
重新构建后授权依然有效。打包完成后可用 `codesign -d -r- build/OpenType.app` 确认不再是 `cdhash`。
