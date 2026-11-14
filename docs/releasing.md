# Releasing

Only cut a release when asked to. This page documents the process and how the in-app updater consumes a release. The authoritative checklist for contributors and agents is [AGENTS.md](../AGENTS.md#publishing-a-release); keep the two in sync.

Throughout, `<version>` is `MARKETING_VERSION` (for example `0.1.4`) and `<build>` is `CURRENT_PROJECT_VERSION` (for example `5`). The release title is `OpenType <version> (<build>)`.

## Checklist

### 1. Release notes

Write notes under `release-notes/<version>/`, based on `git log` since the previous tag.

From 0.1.4 (5) onward every version folder holds five files, one per language, with the same substance:

| File | Language |
| --- | --- |
| `release-notes.md` | English (the default) |
| `release-notes.zh-Hans.md` | Simplified Chinese |
| `release-notes.zh-Hant.md` | Traditional Chinese |
| `release-notes.ja.md` | Japanese |
| `release-notes.ko.md` | Korean |

Rules:

- **Language switcher.** The very first line of each file is one line of five links, in this order, including the file's own language: `[English](…) · [简体中文](…) · [繁體中文](…) · [日本語](…) · [한국어](…)`. The English file is also rendered on the GitHub Release page, where relative links do not resolve, so use **absolute URLs pinned to the version tag**, for example `https://github.com/KryptonGao/OpenType/blob/v<version>/release-notes/<version>/release-notes.zh-Hans.md`.
- **Complete content in every file.** Not a truncated summary. Use the app's own UI terms from `Localizable.xcstrings`.
- **Each file includes**:
  - the system requirements line near the top: **macOS 26.0+ · Apple Silicon (arm64)**, repeated in the requirements section and the download table;
  - install and first-launch (Gatekeeper) instructions for the self-signed build;
  - the download table with the exact asset names below (asset names are not translated).
- **The GitHub Release uses the English file.** The other four are only committed and reached through the links.

### 2. Verify

1. Run the tests.
2. Build and re-sign the Release app exactly as in [Development](development.md#packaging-a-local-build).
3. Check the app:

   ```bash
   codesign --verify --deep --strict build/OpenType.app
   codesign -d -r- build/OpenType.app          # must not be cdhash
   lipo -archs build/OpenType.app/Contents/MacOS/OpenType   # arm64
   /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/OpenType.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c "Print CFBundleVersion" build/OpenType.app/Contents/Info.plist
   ```

   The two versions must match the intended release.

### 3. Package into `dist/`

`dist/` is git-ignored. **Asset names must carry the `-arm64` suffix.** The updater looks for it.

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

### 4. Commit and tag on `main`

No branch or PR. Commit `release-notes/`, then:

```bash
git tag -a v<version> -m "OpenType <version> (<build>)"
git push origin main
git push origin v<version>
```

Pushes to GitHub sometimes fail with a transient `SSL_ERROR_SYSCALL`. Retry a few times with a short sleep before giving up.

### 5. Create the GitHub Release

```bash
gh release create v<version> dist/OpenType-<version>-arm64.dmg dist/OpenType-<version>-arm64.zip \
  --title "OpenType <version> (<build>)" \
  --notes-file release-notes/<version>/release-notes.md --verify-tag
```

Then confirm it is published, not a draft, and both assets are uploaded:

```bash
gh release view v<version> --json isDraft,assets
```

Open the Release page once and click all five language links to confirm they resolve.

### 6. Report

Tell the user the Release URL and the local `dist/` paths.

## Fixing a published release

- **Notes:** edit the notes file, commit and push, then `gh release edit v<version> --notes-file …`.
- **Assets:** `gh release upload --clobber` to replace, `gh release delete-asset` to remove.
- **Tags:** do not delete or move a tag that has already been published without asking first.

## How the in-app updater works

`AppUpdater` and `UpdateInstaller` (in `OpenType/Services/Update/`) turn a GitHub Release into an installed update with no extra infrastructure.

### Detection

- It calls `GET https://api.github.com/repos/KryptonGao/OpenType/releases/latest`.
- The release's `tag_name` is parsed as a dotted version (a leading `v` and any `-suffix` are ignored). Drafts and prereleases are rejected.
- It picks the first uploaded asset whose name ends in `-arm64.dmg`. No such asset means "no compatible asset".
- A newer version is one that compares greater than `CFBundleShortVersionString`.
- **Schedule:** the first check runs 8 seconds after launch. Afterwards an hourly tick checks only if the last check is more than six hours old. Disable it with **Check for updates automatically**.
- When a newer version is found, a notification is shown once per version.

### Download and verification

1. Download the DMG into `~/Library/Caches/com.opentype.OpenType/Updates/<version>/`. The size must match the asset's size.
2. If GitHub supplied a `digest` (`sha256:…`), the SHA-256 of the file must match.
3. Mount it read-only with `hdiutil attach -nobrowse -readonly`, copy the app out with `ditto`, and detach.
4. The app in the image must have the same bundle identifier as the running app and the announced version.
5. Verify the code signature with a strict, nested, all-architectures validity check. When the running app has a real signing identity (its designated requirement is not a `cdhash`), the new app must also satisfy that requirement. Same bundle ID and certificate is required. A running ad-hoc build has no identity to compare, so only validity is checked.

### Install

Installation waits until no dictation is running. It also requires the current bundle to be replaceable (a writable parent directory, not on a read-only volume, not under App Translocation).

OpenType starts a detached shell script and quits. The script:

1. waits for the process to exit (up to about 30 seconds);
2. moves the installed app to `OpenType.app.updating-old`;
3. copies the new app into place with `ditto`, removes the quarantine attribute, and deletes the backup. If the copy fails it restores the old app;
4. opens the app again and removes its work directory.

Leftover work from interrupted updates is deleted at the next launch.

**Download and install updates automatically** is off by default. With it off, the user clicks **Update** in the menu or Settings.

### What this means for releases

- Keep the `-arm64.dmg` naming.
- Sign every release with the **same** certificate as the previous one, or existing installs will refuse the update (and would lose their permission grants anyway).
- Make sure the app inside the DMG has the version number the tag announces.
- Publish a normal release, not a draft or prerelease, for users to see it.
