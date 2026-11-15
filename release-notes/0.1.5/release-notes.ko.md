[English](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.5/release-notes/0.1.5/release-notes.ko.md)

# OpenType 0.1.5 (6)

이번 릴리스에서는 **프리셋과 앱별 규칙**을 추가하고 **마이크 입력 장치 고정**을 지원합니다.

> **시스템 요구 사항: macOS 26.0+ · Apple 실리콘(arm64)**

## 새로운 기능 및 개선 사항

- **프리셋**: 하나로 고정되어 있던 프롬프트를 새 「프리셋」 탭에서 관리하는 프리셋으로 바꿨습니다. 각 프리셋에는 고유한 프롬프트가 있고, 문장 끝 마침표 제거, 반각 문장부호, 켤 사전 팩을 선택할 수 있습니다. 기본 제공 프리셋은 일상 정리(기존 동작), 일상 대화, 업무 이메일, 코드 및 기술 질문, Terminal 명령 생성입니다. 직접 프리셋을 만들거나 기본 제공 프리셋을 복원할 수도 있습니다.
- **앱 규칙**: 녹음을 시작할 때 최상단 앱을 Bundle ID로 찾아 그 앱에 지정한 프리셋을 사용합니다. 앱은 「응용 프로그램」 폴더에서 추가하며, 처음에는 아무것도 등록되어 있지 않습니다. 기본 프리셋과 앱별 자동 선택은 메뉴 막대에서 전환할 수 있고, 한 번의 녹음에 한해서는 오버레이에서 프리셋을 바꿀 수 있습니다.
- **Terminal 명령 생성**: 명령 프리셋은 한 줄로 합쳐지며, 입력만 될 뿐 실행되지는 않습니다.
- **마이크 고정**: 「설정 → 음성 인식」 또는 메뉴 막대에서 입력 장치(내장, USB, Bluetooth, 연속성 카메라 등)를 지정할 수 있습니다. 내장 또는 외장 마이크로 고정하면 AirPods 등 Bluetooth 헤드폰으로 음악을 듣거나 회의에 참여하는 중에도 저음질 통화 모드로 전환되지 않습니다. 선택한 마이크가 Bluetooth이거나 연결이 끊겨 있으면 OpenType이 알려 줍니다.

## 시스템 요구 사항

- **macOS 26.0 이상**.
- **Apple 실리콘(arm64) 전용**이며 Intel Mac은 지원하지 않습니다.
- 시스템 설정의 「개인정보 보호 및 보안」에서 **마이크**, **손쉬운 사용**, **입력 모니터링** 권한을 허용해야 합니다.
- Alibaba Cloud Bailian 또는 DeepSeek(음성 인식)의 API 키와, 선택한 LLM 서비스의 API 키를 직접 준비해야 합니다.

## 설치 및 업그레이드

0.1.3 이상을 사용 중이라면 앱 안에서 업데이트할 수 있습니다(설정 → 업데이트 확인). 그렇지 않다면 `OpenType-0.1.5-arm64.dmg`(또는 `OpenType-0.1.5-arm64.zip`)를 내려받아 `OpenType.app`을 「응용 프로그램」 폴더로 끌어다 놓아 이전 버전을 교체하세요.

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
| `OpenType-0.1.5-arm64.dmg` | 디스크 이미지. 「응용 프로그램」으로 끌어다 놓습니다(macOS 26.0+, arm64) |
| `OpenType-0.1.5-arm64.zip` | 압축 파일. 풀면 `OpenType.app`이 나옵니다(macOS 26.0+, arm64) |
