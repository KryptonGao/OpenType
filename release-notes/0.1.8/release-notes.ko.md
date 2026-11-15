[English](https://github.com/KryptonGao/OpenType/blob/v0.1.8/release-notes/0.1.8/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.8/release-notes/0.1.8/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.8/release-notes/0.1.8/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.8/release-notes/0.1.8/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.8/release-notes/0.1.8/release-notes.ko.md)

# OpenType 0.1.8 (9)

이번 업데이트에서는 중국 밖의 사용자를 위해 설정에 **알리바바 클라우드 바이롄(Bailian)**과 **DeepSeek**의 공식 사이트 링크를 추가했습니다.

> **시스템 요구 사항: macOS 26.0+ · Apple 실리콘(arm64)**

## 새로운 기능과 개선

- **공식 사이트 링크**: 알리바바 클라우드 바이롄과 DeepSeek은 중국 밖에서는 잘 알려져 있지 않으므로, 앱 언어가 간체 중국어가 아닐 때 설정의 API 키 입력란 아래에 공식 사이트 링크를 표시합니다(음성 인식 → 알리바바 클라우드 바이롄, 음성 인식 → DeepSeek, 대신 말하기 → 웹 검색(DeepSeek)). 링크를 누르면 공식 사이트가 열리며 API 키를 발급받을 수 있습니다. 링크 문구는 5개 앱 언어로 번역되어 있으며, 간체 중국어 UI는 그대로입니다.

## 시스템 요구 사항

- **macOS 26.0 이상**.
- **Apple 실리콘(arm64) 전용**이며 Intel Mac은 지원하지 않습니다.
- 시스템 설정의 「개인정보 보호 및 보안」에서 **마이크**, **손쉬운 사용**, **입력 모니터링** 권한을 허용해야 합니다.
- Alibaba Cloud Bailian 또는 DeepSeek(음성 인식)의 API 키와, 선택한 LLM 서비스의 API 키를 직접 준비해야 합니다.

## 설치 및 업그레이드

0.1.3 이상을 사용 중이라면 앱 안에서 업데이트할 수 있습니다(설정 → 업데이트 확인). 그렇지 않다면 `OpenType-0.1.8-arm64.dmg`(또는 `OpenType-0.1.8-arm64.zip`)를 내려받아 `OpenType.app`을 「응용 프로그램」 폴더로 끌어다 놓아 이전 버전을 교체하세요.

이 빌드는 자체 서명 인증서로 서명되었고 Apple의 공증을 받지 않았으므로, 처음 실행할 때 Gatekeeper가 차단합니다. 다음 중 하나로 허용하세요.

- 시스템 설정 → 개인정보 보호 및 보안에서 「그래도 열기」를 클릭합니다.
- 또는 터미널에서 다음을 실행합니다.

```bash
xattr -dr com.apple.quarantine /Applications/OpenType.app
```

> 같은 인증서로 서명된 업그레이드라면 이미 허용한 손쉬운 사용 / 입력 모니터링 권한이 유지됩니다.

## 다운로드

| 파일 | 설명 |
|---|---|
| `OpenType-0.1.8-arm64.dmg` | 디스크 이미지. 「응용 프로그램」으로 끌어다 놓습니다(macOS 26.0+, arm64) |
| `OpenType-0.1.8-arm64.zip` | 압축 파일. 풀면 `OpenType.app`이 나옵니다(macOS 26.0+, arm64) |
