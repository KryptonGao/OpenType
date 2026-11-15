[English](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.6/release-notes/0.1.6/release-notes.ko.md)

# OpenType 0.1.6 (7)

이번 릴리스에서는 **업데이트 창**을 새로 디자인하고 **데이터를 `~/.opentype`의 읽기 쉬운 파일로 저장**합니다.

> **시스템 요구 사항: macOS 26.0+ · Apple 실리콘(arm64)**

## 새로운 기능 및 개선 사항

- **업데이트 창**: 업데이트를 확인하면 앱 아이콘, 새 버전, 릴리스 노트(렌더링된 Markdown, UI 언어)가 담긴 작은 「소프트웨어 업데이트」 창이 열립니다. 「이 버전 건너뛰기」, 「나중에」, 「업데이트 설치」 중에서 고를 수 있고, 설치를 시작하면 내려받은 바이트 수와 취소 버튼이 있는 별도의 진행 창으로 바뀝니다. 최신 버전이거나 오류가 났을 때는 시스템 표준 알림으로 알려 주며, 건너뛴 버전은 백그라운드 확인에서 다시 알리지 않습니다. 설정에 있던 릴리스 노트 펼침 항목은 없어졌습니다.
- **`~/.opentype`에 데이터 저장**: 모든 설정(`settings.json`), 프리셋과 앱 규칙(`presets.json`), 사전(`dictionary.json`), 기록(`history.json`)이 `~/.opentype`의 평문 JSON 파일로 저장됩니다. 개발 빌드와 릴리스 빌드가 공유하며, 백업하거나 다른 Mac으로 복사하기도 쉽습니다. 이전 버전의 설정, 프리셋, 기록은 처음 실행할 때 한 번 자동으로 옮겨집니다.

## 시스템 요구 사항

- **macOS 26.0 이상**.
- **Apple 실리콘(arm64) 전용**이며 Intel Mac은 지원하지 않습니다.
- 시스템 설정의 「개인정보 보호 및 보안」에서 **마이크**, **손쉬운 사용**, **입력 모니터링** 권한을 허용해야 합니다.
- Alibaba Cloud Bailian 또는 DeepSeek(음성 인식)의 API 키와, 선택한 LLM 서비스의 API 키를 직접 준비해야 합니다.

## 설치 및 업그레이드

0.1.3 이상을 사용 중이라면 앱 안에서 업데이트할 수 있습니다(설정 → 업데이트 확인). 그렇지 않다면 `OpenType-0.1.6-arm64.dmg`(또는 `OpenType-0.1.6-arm64.zip`)를 내려받아 `OpenType.app`을 「응용 프로그램」 폴더로 끌어다 놓아 이전 버전을 교체하세요.

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
| `OpenType-0.1.6-arm64.dmg` | 디스크 이미지. 「응용 프로그램」으로 끌어다 놓습니다(macOS 26.0+, arm64) |
| `OpenType-0.1.6-arm64.zip` | 압축 파일. 풀면 `OpenType.app`이 나옵니다(macOS 26.0+, arm64) |
