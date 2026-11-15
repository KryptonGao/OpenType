# AGENTS.md

## Commits and branches

**Do not `git commit` or `git push` on your own.** After making changes, leave them uncommitted in the working tree and wait until the user explicitly says to commit / push (e.g. "commit", "commit and push", "push it"). Only then commit (and push, if asked). A request to commit does not imply a push, and an approval to commit once does not carry over to later changes.

When the user does ask you to commit, commit directly to the `main` branch (do not create a new branch or open a PR) unless they explicitly say "submit a PR / open a PR", in which case follow the branch + PR flow.

The release flow under "Publishing a release" is the one exception: when the user asks to publish a release, its commit / tag / push steps are authorized by that request.

## README languages

The README exists in five languages, matching the app's UI languages: `README.md` (English, the GitHub default), `README.zh-Hans.md`, `README.zh-Hant.md`, `README.ja.md`, `README.ko.md`. When you change user-facing README content, update all five. Each has its own localized hero / modes images in `assets/readme/` (`hero.<lang>.svg`, `modes.<lang>.svg`). Use the app's own UI terms from `OpenType/Resources/Localizable.xcstrings` (e.g. 帮我说 / 幫我說 / Say It for Me / 代わりに話す / 대신 말하기).

## Package a new .app for testing (only when needed)

Do **not** package a new `.app` after every change. After a code change (once the build/tests pass), use your own judgment on whether the user needs a fresh `.app` to test it:

- **Package** when the change affects runtime behavior the user would want to try by hand: UI, overlay, shortcuts, permissions, audio / transcription / translation / writing-tools flows, settings, prompts, anything involving the signed app's system permissions.
- **Don't package** for changes that can't be observed in the running app or are already fully covered by tests: documentation (README, AGENTS.md, release notes), comments, refactors with no behavior change, test-only changes, localization-file typos you can verify by reading, etc.
- If it is unclear, or the user says "don't package" / "package it", follow the user. When you skip packaging, you may say in one short line that you did.

When you do package, use:

```bash
xcodebuild build -project OpenType.xcodeproj -scheme OpenType -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
&& rm -rf build/OpenType.app \
&& cp -R build/DerivedData/Build/Products/Release/OpenType.app build/OpenType.app \
&& codesign --force --sign "OpenType Self-Signed" \
     --options runtime --entitlements OpenType/OpenType.entitlements build/OpenType.app
```

- Output path: `build/OpenType.app` (`build/` is in `.gitignore`, so it is not committed).
- When finished, tell the user the path of the .app in your reply.
- Test command: `xcodebuild test -project OpenType.xcodeproj -scheme OpenType -destination 'platform=macOS'`.

### Re-sign with the fixed certificate (important)

The project defaults to ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`), whose designated requirement is the code hash (cdhash), which **changes on every build**.
macOS records the Accessibility / Input Monitoring grants per signing identity, so after an ad-hoc build the grants become invalid: the toggles in System Settings are still on, but the app actually has no permission (global shortcuts stop working).

Therefore, after packaging you must re-sign with the fixed self-signed certificate `OpenType Self-Signed` (the last step of the command above). This makes the designated requirement "bundle id + certificate", so the grants remain valid across rebuilds.
After packaging, you can run `codesign -d -r- build/OpenType.app` to confirm it is no longer `cdhash`.

- The certificate is a locally generated self-signed code-signing certificate (valid for 10 years) stored in the login keychain; a backup is at `~/OpenType-Signing/OpenType-Signing.p12` (never commit it to the repository).
- Use the same certificate to sign builds distributed to others, so their grants also survive updates. A self-signed app cannot pass Gatekeeper: on first launch, users must click "Open Anyway" in System Settings → Privacy & Security,
  or run `xattr -dr com.apple.quarantine /Applications/OpenType.app`.
- If the certificate is lost or replaced, the signing identity changes, and every user (and this machine) must re-grant Accessibility / Input Monitoring.
- To eliminate the first-launch warning in the future, join the Apple Developer Program, sign with a Developer ID Application certificate, and notarize with `notarytool`.

## Publishing a release

Only when the user asks to publish / ship a release. Replace `<version>` with `MARKETING_VERSION` (e.g. `0.1.0`); the build number is `CURRENT_PROJECT_VERSION` (e.g. `1`). The Release title is `OpenType <version> (<build>)`, e.g. `OpenType 0.1.0 (1)`.

1. **Release notes**: write the notes under `release-notes/<version>/` (one folder per version under `release-notes/` at the repo root). Base them on `git log` since the previous tag.
   - **Languages and files**: versions before 0.1.4 (5) have a single Simplified Chinese `release-notes.md`. **From 0.1.4 (5) onward, every version folder holds five files, one per language, matching the app's UI languages and the README naming** (never put several languages in one file):

     | File | Language |
     | --- | --- |
     | `release-notes.md` | English (the default) |
     | `release-notes.zh-Hans.md` | 简体中文 |
     | `release-notes.zh-Hant.md` | 繁體中文 |
     | `release-notes.ja.md` | 日本語 |
     | `release-notes.ko.md` | 한국어 |

   - **The Release uses the English file**: `gh release create --notes-file release-notes/<version>/release-notes.md` (see step 5). The other four files are only committed to the repo and reached through links.
   - **Language switcher**: at the very top of every one of the five files (above everything else), put one line with five hyperlinks, in this order, one per language, including the file's own language: `[English](…) · [简体中文](…) · [繁體中文](…) · [日本語](…) · [한국어](…)`. Because the English file is also rendered on the GitHub Release page, where relative links do not resolve, **use absolute URLs pinned to the version tag**, e.g. `https://github.com/KryptonGao/OpenType/blob/v<version>/release-notes/<version>/release-notes.zh-Hans.md` (the tag is pushed in step 4, before the Release is created in step 5). After publishing, open the Release page once and click all five links to confirm they resolve.
   - **Content**: each of the five files carries the complete notes (not a truncated summary) and they must stay equivalent in substance. Use the app's own UI terms from `OpenType/Resources/Localizable.xcstrings` (same as the README). Each file must include:
     - the system requirements line near the top: **macOS 26.0+ · Apple Silicon (arm64)** (also repeated in the requirements section and the download table; the binary is arm64-only, verify with `lipo -archs`);
     - the install / first-launch (Gatekeeper) instructions for the self-signed build;
     - the download table with the exact asset names below (asset names are not translated).
2. **Verify**: run the tests, then build and re-sign the Release `.app` exactly as in the section above. Confirm `codesign --verify --deep --strict build/OpenType.app`, that the designated requirement is not `cdhash`, and that `CFBundleShortVersionString` / `CFBundleVersion` match the intended version.
3. **Package into `dist/`** (`dist/` is in `.gitignore`). **Asset names must carry the `-arm64` suffix**:

   ```bash
   V=<version>
   rm -rf dist && mkdir -p dist/dmg-stage
   ditto -c -k --sequesterRsrc --keepParent build/OpenType.app dist/OpenType-$V-arm64.zip
   cp -R build/OpenType.app dist/dmg-stage/ && ln -s /Applications dist/dmg-stage/Applications
   hdiutil create -volname "OpenType $V" -srcfolder dist/dmg-stage -ov -format UDZO dist/OpenType-$V-arm64.dmg
   codesign --force --sign "OpenType Self-Signed" dist/OpenType-$V-arm64.dmg
   rm -rf dist/dmg-stage
   hdiutil verify dist/OpenType-$V-arm64.dmg
   ```

   Also check that the zip extracts to an app that still passes `codesign --verify --deep --strict`.
4. **Commit and tag on `main`** (no branch / PR): commit `release-notes/`, then `git tag -a v<version> -m "OpenType <version> (<build>)"`, then `git push origin main` and `git push origin v<version>`.
5. **Create the GitHub Release** with `gh`:

   ```bash
   gh release create v<version> dist/OpenType-<version>-arm64.dmg dist/OpenType-<version>-arm64.zip \
     --title "OpenType <version> (<build>)" \
     --notes-file release-notes/<version>/release-notes.md --verify-tag
   ```

   Afterwards check with `gh release view v<version> --json isDraft,assets` that it is not a draft and both assets are `uploaded`.
6. Tell the user the Release URL and the local `dist/` paths.

Notes:

- Pushes to GitHub sometimes fail with a transient `SSL_ERROR_SYSCALL`; retry a few times (e.g. a short loop with `sleep`) before giving up.
- To change the notes or rename assets after publishing: edit the notes file, commit and push, then `gh release edit v<version> --notes-file ...`; for assets use `gh release upload --clobber` and `gh release delete-asset`. Do not delete or move a tag that has already been published without asking the user.
