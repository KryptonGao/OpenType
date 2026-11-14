[English](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.md) · [简体中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hans.md) · [繁體中文](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.zh-Hant.md) · [日本語](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ja.md) · [한국어](https://github.com/KryptonGao/OpenType/blob/v0.1.4/release-notes/0.1.4/release-notes.ko.md)

# OpenType 0.1.4 (5)

이번 업데이트에서는 메인 창을 새로 디자인하여 **네이티브 사이드바 레이아웃**을 적용했습니다. OpenType이 한층 더 표준 macOS 앱답게 보이고 동작합니다.

> **시스템 요구 사항: macOS 26.0 이상 · Apple 실리콘(arm64)**

## 새로운 기능 및 개선 사항

- **네이티브 사이드바 레이아웃**: 메인 창이 사이드바 형태로 바뀌어 「홈」「기록」「사전」이 먼저 나오고, 그 아래에 여섯 개의 설정 페이지를 담은 「설정」 섹션이 이어집니다. 설정 탭 안의 분할 전환기는 사라졌습니다.
- **홈**: 상단에 단축키 상태 카드를 추가하고, 통계는 테두리가 있는 한 줄 그룹으로 묶었으며, 기간 선택기는 창 도구 막대로 옮겼습니다.
- **기록 및 사전**: 네이티브 검색 필드와 도구 막대 항목을 사용하고, 스위치 컨트롤을 더 작게 만들었으며, 사전 팩은 그룹형 양식으로 표시됩니다.
- **메뉴 막대와 오버레이**: 메뉴 막대 메뉴에 SF Symbols와 상태 아이콘을 추가했고, 오버레이 카드는 모서리를 더 둥글게 하고 상태 아이콘을 표시합니다.

## 시스템 요구 사항

- **macOS 26.0 이상**.
- **Apple 실리콘(arm64)만 지원**하며 Intel Mac은 지원하지 않습니다.
- 시스템 설정의 「개인정보 보호 및 보안」에서 **마이크**, **손쉬운 사용**, **입력 모니터링** 권한을 허용해야 합니다.
- 알리바바 클라우드 바이롄(Bailian) 또는 DeepSeek의 API 키(ASR)와 선택한 LLM 서비스의 API 키를 직접 준비해야 합니다.

## 설치 및 업그레이드

0.1.3 이상을 사용 중이라면 앱 안에서 바로 업데이트할 수 있습니다(설정에서 업데이트 확인). 그렇지 않다면 `OpenType-0.1.4-arm64.dmg`(또는 `OpenType-0.1.4-arm64.zip`)를 다운로드한 뒤 `OpenType.app`을 「응용 프로그램」 폴더로 끌어다 놓아 이전 버전을 덮어쓰세요.

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
| `OpenType-0.1.4-arm64.dmg` | 디스크 이미지. 「응용 프로그램」으로 끌어다 놓으면 됩니다(macOS 26.0+, arm64) |
| `OpenType-0.1.4-arm64.zip` | 압축 파일. 압축을 풀면 `OpenType.app`을 얻습니다(macOS 26.0+, arm64) |
