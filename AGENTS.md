# AGENTS.md

## Commits and branches

Unless the user explicitly asks for a PR, commit changes directly to the `main` branch (do not create a new branch or open a PR). Only follow the branch + PR flow when the user explicitly says "submit a PR / open a PR".

## Package a new .app after making changes

After every code change (once the build/tests pass), you must package a new Release `.app` for the user to test, unless the user explicitly says "don't package".

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
