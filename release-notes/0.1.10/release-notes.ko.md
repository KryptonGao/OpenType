[English](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.10/release-notes/0.1.10/release-notes.ko.md)

# OpenType 0.1.10 (11)

이번 업데이트에서는 화면의 일부를 선택해 바로 질문할 수 있는 **화면 질문**이 추가되었습니다.

> **시스템 요구 사항: macOS 26.0+ · Apple 실리콘(arm64)**

## 새로운 기능과 개선

- **화면 질문**: 전역 단축키(기본값 ⇧⌘6, '설정 → 화면 질문'에서 변경 가능)를 누르면 화면이 어두워집니다. 질문하고 싶은 영역을 드래그해 선택하면, 8개의 핸들로 크기를 조절하거나 선택 영역을 이동하거나 다시 선택할 수 있습니다. 선택 영역 옆의 글래스 패널이 해당 영역에 대한 질문에 Markdown 스트리밍으로 답합니다. 텍스트나 음성으로 질문할 수 있고, 단축 버튼으로 해당 영역을 Google 이미지 검색에 사용할 수도 있습니다. 답변한 질문은 기록에 텍스트만 저장되며 스크린샷은 저장되지 않습니다.
- **웹 검색 설정 공용화**: 웹 검색과 페이지 읽기가 '설정 → AI 처리'로 옮겨졌습니다(DeepSeek만 지원, 별도의 API 키 사용). '대신 말하기'와 '화면 질문'은 기본적으로 이 설정을 따르며, 각각 켜기/끄기와 적극도를 따로 설정할 수도 있습니다.
- 화면 질문에는 **화면 기록** 권한이 필요하며, 처음 사용할 때 macOS가 허용을 요청합니다.

## 시스템 요구 사항

- **macOS 26.0 이상**.
- **Apple 실리콘(arm64) 전용**이며 Intel Mac은 지원하지 않습니다.
- 시스템 설정의 「개인정보 보호 및 보안」에서 **마이크**, **손쉬운 사용**, **입력 모니터링** 권한을 허용해야 합니다. 화면 질문에는 **화면 기록** 권한도 필요합니다.
- Alibaba Cloud Bailian 또는 DeepSeek(음성 인식)의 API 키와, 선택한 LLM 서비스의 API 키를 직접 준비해야 합니다.

## 설치 및 업그레이드

0.1.3 이상을 사용 중이라면 앱 안에서 업데이트할 수 있습니다(설정 → 업데이트 확인). 그렇지 않다면 `OpenType-0.1.10-arm64.dmg`(또는 `OpenType-0.1.10-arm64.zip`)를 내려받아 `OpenType.app`을 「응용 프로그램」 폴더로 끌어다 놓아 이전 버전을 교체하세요.

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
| `OpenType-0.1.10-arm64.dmg` | 디스크 이미지. 「응용 프로그램」으로 끌어다 놓습니다(macOS 26.0+, arm64) |
| `OpenType-0.1.10-arm64.zip` | 압축 파일. 풀면 `OpenType.app`이 나옵니다(macOS 26.0+, arm64) |
