# 기여 가이드

관심 가져 주셔서 고맙습니다. 시작하기 전에 두 가지를 알아 두세요.

1. 이 저장소는 **소스 공개(source-available)** 이며 [PolyForm Noncommercial 1.0.0](LICENSE) 을 따릅니다. 비상업 목적의 수정·포크는 가능하지만 상업적 이용은 불가합니다.
2. PR 을 보내면 그 기여물에도 같은 라이선스가 적용되는 것에 동의한 것으로 봅니다.

## 먼저 이슈로 이야기해 주세요

코드를 쓰기 전에 [이슈](https://github.com/Cassiiopeia/EarLocAlert/issues) 를 열어 무엇을 왜 바꾸려는지 알려 주세요. 방향이 맞지 않으면 작업이 낭비될 수 있습니다. 버그는 앱 버전, 플랫폼·기기, 재현 절차를 적어 주세요. 설정 → 진단 기록을 내보낸 파일이 있으면 가장 빨리 원인을 찾을 수 있습니다.

## 지켜야 하는 핵심 원칙

이 앱의 존재 이유와 직결되어 **예외가 없습니다.** 자세한 이유는 [CLAUDE.md](CLAUDE.md) 와 `docs/` 에 있습니다.

- 이어폰 연결을 확인하지 않고 **소리를 재생하지 않습니다.** 확인에 실패하면 진동으로 떨어집니다
- 알림 해제는 광고를 기다리지 않습니다. 알림 화면에 광고를 겹치지 않습니다
- 로그는 `print` 가 아니라 `Diagnostics` 로 남깁니다
- 화면 문자열은 하드코딩하지 않고 네 언어 l10n 을 씁니다 (`context.l10n.키`)
- 상태 관리는 `@riverpod` code generation 만 씁니다

## 개발 환경

- Flutter 3.35.5 (Dart 3.9+) — 더 높은 버전은 code generation 이 동작하지 않을 수 있습니다
- 지도를 보려면 `.env.example` 을 `.env` 로 복사해 `MAPS_API_KEY` 를 채웁니다. 없어도 빌드는 되고 지도만 회색으로 보입니다
- 실기기 테스트에 **실제 광고 ID 를 쓰지 마세요.** 디버그 빌드는 테스트 광고 ID 로 자동 분기됩니다

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

## PR 보내기

- 변경은 작게, 한 PR 에 한 가지 목적만 담아 주세요
- 설계 판단을 바꿨다면 [10-DECISIONS](docs/10-DECISIONS.md) 에 항목을 추가해 주세요
- `pubspec.yaml` 의 version 은 수정하지 마세요. `version.yml` 이 단일 출처입니다
- 실기기에서만 확인되는 변경(백그라운드, 오디오 경로)은 어떤 기기에서 확인했는지 적어 주세요

## 보안 문제

취약점은 공개 이슈로 올리지 말고 [SECURITY.md](SECURITY.md) 의 방법으로 알려 주세요.
