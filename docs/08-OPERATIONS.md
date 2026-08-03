# 08. 운영

**이 프로젝트에서 유일하게 이미 완성된 영역이다.** 앱 코드는 없지만 배포 파이프라인은 동작한다.

앞으로 할 일은 이걸 새로 만드는 것이 아니라 **이 통로에 실어 보낼 물건을 만드는 것**이고, 그 과정에서 아래 정리된 관리 포인트를 건드리게 된다.

## 브랜치와 배포 흐름

```
feature 브랜치
   └─ PR → main
        ├─ PR CI               빌드·분석 검증
        └─ merge
             ├─ 버전 자동 증가   version.yml → pubspec.yaml 동기화
             ├─ CHANGELOG 생성
             └─ Play Store 내부 테스트 배포

deploy 브랜치 push  →  Play Store 배포
수동 실행           →  TestFlight 배포
```

## 워크플로우

| 파일 | 하는 일 |
|---|---|
| `PROJECT-COMMON-VERSION-CONTROL` | `version.yml` 의 patch·build number 자동 증가 후 `pubspec.yaml` 동기화 |
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` | PR 병합 시 CHANGELOG 갱신 |
| `PROJECT-COMMON-README-VERSION-UPDATE` | README 버전 배지·표 갱신 |
| `PROJECT-COMMON-SYNC-ISSUE-LABELS` | 이슈 라벨 동기화 |
| `PROJECT-COMMON-QA-ISSUE-CREATION-BOT` | QA 이슈 생성 |
| `PROJECT-COMMON-SUH-ISSUE-HELPER-*` | 이슈 헬퍼 연동 |
| `PROJECT-FLUTTER-ANDROID-PR-CI` | PR 빌드 검증 |
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD` | Play Store 내부 테스트 배포 |
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD` | APK 를 NAS 로 배포 |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT` | TestFlight 배포 |
| `PROJECT-FLUTTER-IOS-CICD` | iOS 빌드 산출물 NAS 배포 |
| `PROJECT-TEMPLATE-INITIALIZER` · `TEMPLATE-UTIL-VERSION-SYNC` | 템플릿 초기화·동기화 |

## 버전 관리 — `version.yml` 이 단일 출처

```yaml
version: "1.2.17"
version_code: 50        # 스토어 빌드 번호
project_type: "flutter"
```

**`pubspec.yaml` 의 버전을 직접 고치지 않는다.** 워크플로우가 `version.yml` 을 읽어 동기화한다. 손으로 고치면 다음 배포에서 덮어써진다.

- patch 는 자동 증가
- minor·major 는 `version.yml` 을 직접 수정
- `version_code` 는 매 빌드 자동 증가 — 스토어는 같은 번호를 두 번 받지 않는다

---

## 지금 고쳐야 할 것 — 템플릿 잔재

이 파이프라인은 [SUH-DEVOPS-TEMPLATE](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE) 에서 가져온 것이라, **아직 템플릿 기본값이 남아 있다.** 실제 배포 전에 확인한다.

### 1. `PROJECT_NAME` 이 `"your-project"` 다

`PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` 의 env 값이 템플릿 기본값 그대로다. 배포 산출물 이름·알림 문구에 그대로 쓰인다.

### 2. 시크릿 이름이 워크플로우마다 다르다

같은 키스토어를 가리키는데 이름이 갈린다.

| 용도 | PR CI | Play Store CI/CD |
|---|---|---|
| 키스토어 | `KEYSTORE_FILE` | `RELEASE_KEYSTORE_BASE64` |
| 키스토어 비밀번호 | `KEYSTORE_PASSWORD` | `RELEASE_KEYSTORE_PASSWORD` |
| 키 별칭 | `KEY_ALIAS` | `RELEASE_KEY_ALIAS` |
| 키 비밀번호 | `KEY_PASSWORD` | `RELEASE_KEY_PASSWORD` |
| 환경 파일 | `ENV` | `ENV_FILE` |

**둘 다 등록해두면 동작은 한다.** 하지만 키스토어를 교체할 때 한쪽만 갱신하면 그때 깨지고, 원인을 찾는 데 시간이 걸린다. 실제 배포에 들어가기 전에 한쪽으로 통일한다.

---

## 시크릿

### Android

| 시크릿 | 용도 |
|---|---|
| `RELEASE_KEYSTORE_BASE64` | 앱 서명 키스토어 |
| `RELEASE_KEYSTORE_PASSWORD` · `RELEASE_KEY_ALIAS` · `RELEASE_KEY_PASSWORD` | 키스토어 접근 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` | Play Console 업로드 |
| `GOOGLE_SERVICES_JSON` | Google 서비스 설정 |
| `ENV_FILE` | 앱 런타임 환경 변수 |

**키스토어를 잃어버리면 그 앱은 끝이다.** 같은 패키지명으로 업데이트를 올릴 수 없고, 새 패키지명으로 다시 출시하면 기존 사용자·리뷰·순위가 전부 사라진다.

로컬 `playstore-secrets/` 에 실물이 있다 — `release-key.jks`, `service-account.json`, `github-secrets`.

**이 디렉터리는 `.gitignore` 에 없었다 (2026-08-03 발견, 같은 날 추가).** `release-key.jks` 만 `*.jks` 패턴에 우연히 걸려 있었고, **Play Console 배포 권한을 가진 `service-account.json` 은 추적 대상이었다.** 커밋됐다면 저장소를 읽을 수 있는 누구나 이 앱을 스토어에 올릴 수 있었다.

> **교훈** — 시크릿 디렉터리를 만들면 그 자리에서 `.gitignore` 에 넣고 `git check-ignore` 로 확인한다. 확장자 패턴에 우연히 걸리는 것에 기대지 않는다.

그리고 gitignore 되어 있다는 것은 **이 PC 가 죽으면 같이 죽는다**는 뜻이다. 별도 백업이 있는지 확인한다. 키스토어는 코드처럼 다시 만들 수 있는 것이 아니다.

### iOS

| 시크릿 | 용도 |
|---|---|
| `APPLE_CERTIFICATE_BASE64` · `APPLE_CERTIFICATE_PASSWORD` | 서명 인증서 |
| `APPLE_PROVISIONING_PROFILE_BASE64` · `IOS_PROVISIONING_PROFILE_NAME` | 프로비저닝 |
| `APP_STORE_CONNECT_API_KEY_BASE64` · `_KEY_ID` · `_ISSUER_ID` | 업로드 인증 |
| `SECRETS_XCCONFIG` | 빌드 설정 주입 |
| `ENV` | 앱 런타임 환경 변수 |

인증서와 프로비저닝 프로필은 **만료된다.** 만료 시점을 알기 어려운데, 빌드가 갑자기 실패하면 여기를 먼저 본다.

---

## 앱이 필요로 하는 키

앞으로 추가될 것들이다. 지금은 없지만 구현하면 반드시 필요하다.

| 키 | 쓰는 곳 | 주의 |
|---|---|---|
| Google Maps API 키 (Android) | `AndroidManifest.xml` | **패키지명 + 서명 인증서로 제한한다** |
| Google Maps API 키 (iOS) | `AppDelegate` | 번들 ID 로 제한 |
| AdMob 앱 ID | 매니페스트 · plist | 공개 정보 — 숨길 필요 없다 |
| AdMob 광고 단위 ID | 코드 | 빌드 종류로 자동 분기 |

### Maps API 키는 반드시 제한을 건다

APK 를 뜯으면 키가 보인다. **제한을 걸지 않으면 남이 내 키로 API 를 호출하고 과금이 나에게 온다.**

- Android: 패키지명 + SHA-1 인증서 지문
- iOS: 번들 ID
- 사용량 상한(quota) 설정

### 광고 ID 는 빌드가 결정한다

```
디버그 빌드   → 테스트 광고 ID
릴리스 빌드   → 프로덕션 광고 ID
```

**사람이 기억해서 바꾸지 않는다.** 실기기 테스트에서 실제 광고 ID 를 쓰면 무효 트래픽으로 집계되고, 반복되면 계정이 정지된다 → [07-MONETIZATION](07-MONETIZATION.md)

---

## 개발 환경 제약 — 이 PC 에서는 빌드할 수 없다

개발 PC 가 내부망이라 **pub.dev 에 접근할 수 없다.** 미러도 없다.

| 명령 | 가능 여부 |
|---|---|
| `flutter pub get` | **불가** |
| `flutter analyze` · `flutter test` · `flutter build` | **불가** (의존성이 없으므로) |
| `dart format` | 가능 |
| 코드 작성 · 문서 작성 · git | 가능 |

**그래서 검증을 CI 에 위임한다.** 로컬에서 확인할 수 없는 것을 PR CI 가 대신 본다. 이건 우회가 아니라 **의도된 구조**다 — 어차피 실기기 검증은 별도 환경에서 해야 하고, 백그라운드 동작과 오디오 라우팅은 로컬 빌드로도 확인할 수 없다.

작업 흐름은 이렇게 된다.

```
내부망 PC:  코드 작성 → dart format → 커밋 → push
                                              ↓
GitHub Actions:                         빌드·분석 검증
                                              ↓
별도 환경:                          실기기 설치 → 인수 조건 확인
```

의존성을 추가할 때는 **`pubspec.yaml` 을 수정한 뒤 CI 결과로 확인한다.** 로컬에서 버전 충돌을 미리 잡을 수 없으므로, 한 번에 여러 패키지를 추가하면 무엇이 문제인지 알기 어렵다. 나눠서 추가한다.

---

## 배포 채널

| 채널 | 용도 | 트리거 |
|---|---|---|
| Play 내부 테스트 | 상시 검증 | main 병합 시 자동 |
| TestFlight | iOS 검증 | 수동 |
| NAS | 임의 APK 공유 | 수동 |
| Play 프로덕션 | 정식 출시 | **수동 승격** |

**프로덕션 승격은 자동화하지 않는다.** 심사 통과 후 사람이 판단해서 올린다 → [09-RELEASE](09-RELEASE.md)
