[English](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/main/release-notes/0.1.3/release-notes.ko.md)

# OpenType 0.1.3 (4)

이번 업데이트에서는 **앱 내 업데이트**가 추가되었습니다. OpenType이 GitHub Release를 스스로 확인하고, 새 버전의 DMG를 다운로드·검증한 뒤 설치까지 마치므로 더 이상 앱을 직접 교체하지 않아도 됩니다.

> **시스템 요구 사항: macOS 26.0 이상 · Apple 실리콘(arm64)**

## 새로운 기능 및 개선 사항

- **앱 내 업데이트**: 설정에서 GitHub Release의 새 버전을 확인하고, 발견되면 DMG 다운로드, 검증, 설치를 앱에서 바로 진행할 수 있습니다.
- **자동 확인 및 자동 설치**: 업데이트를 자동으로 확인할지, 새 버전을 발견하면 자동으로 설치할지 선택할 수 있습니다.
- **메뉴 막대 안내**: 메뉴 막대 메뉴에 업데이트 상태와 업데이트 진입점이 표시됩니다.
- 업데이트 관련 현지화 문구(简体中文, 繁體中文, English, 日本語, 한국어)와 단위 테스트를 추가했습니다.

## 시스템 요구 사항

- **macOS 26.0 이상**.
- **Apple 실리콘(arm64)만 지원**하며 Intel Mac은 지원하지 않습니다.
- 시스템 설정의 「개인정보 보호 및 보안」에서 **마이크**, **손쉬운 사용**, **입력 모니터링** 권한을 허용해야 합니다.
- 알리바바 클라우드 바이롄(Bailian) 또는 DeepSeek의 API 키(ASR)와 선택한 LLM 서비스의 API 키를 직접 준비해야 합니다.

## 설치 및 업그레이드

`OpenType-0.1.3-arm64.dmg`(또는 `OpenType-0.1.3-arm64.zip`)를 다운로드한 뒤 `OpenType.app`을 「응용 프로그램」 폴더로 끌어다 놓아 이전 버전을 덮어쓰세요. 0.1.3부터는 이후 버전을 앱 안에서 바로 업데이트할 수 있습니다.

이 버전은 자체 서명 인증서로 서명되었고 Apple 공증을 거치지 않았기 때문에, 처음 실행할 때 Gatekeeper가 차단합니다. 다음 중 한 가지 방법으로 허용하세요.

- 「시스템 설정 → 개인정보 보호 및 보안」에서 「그래도 열기」를 클릭합니다.
- 또는 터미널에서 다음을 실행합니다.

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 같은 인증서로 서명된 한, 업그레이드 후에도 손쉬운 사용 / 입력 모니터링 권한은 유지됩니다.

## 다운로드

| 파일 | 설명 |
|---|---|
| `OpenType-0.1.3-arm64.dmg` | 디스크 이미지. 「응용 프로그램」으로 끌어다 놓으면 됩니다(macOS 26.0+, arm64) |
| `OpenType-0.1.3-arm64.zip` | 압축 파일. 압축을 풀면 `OpenType.app`을 얻습니다(macOS 26.0+, arm64) |
