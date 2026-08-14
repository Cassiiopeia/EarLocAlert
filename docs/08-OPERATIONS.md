# 08. 운영

**이 프로젝트에서 유일하게 이미 완성된 영역이다.** 앱 코드는 없지만 배포 파이프라인은 동작한다.

앞으로 할 일은 이걸 새로 만드는 것이 아니라 **이 통로에 실어 보낼 물건을 만드는 것**이고, 그 과정에서 아래 정리된 관리 포인트를 건드리게 된다.

## 브랜치와 배포 흐름

```
develop 브랜치 (기본 작업 브랜치)
   ├─ push                    Flutter CI (분석·테스트·빌드)
   └─ PR → main
        ├─ PR CI               빌드·분석·테스트
        └─ merge → main push
             ├─ 버전 자동 증가   version.yml → pubspec.yaml 동기화
             ├─ Play Store 내부 테스트 배포
             ├─ Synology 자체 배포
             └─ TestFlight 배포
```

**deploy 브랜치는 없앴다 (2026-08-06).** 이전에는 Play Store 워크플로우의 `workflow_run` 트리거가 존재하지 않는 워크플로우 이름을 기다려 main 머지만으로 배포가 안 됐고, 그래서 deploy 브랜치 push 로 우회했다. 이제 배포 워크플로우 세 개가 **main push 를 직접 본다** — 별도 브랜치 조작이 필요 없다.

```bash
# 배포 절차
# develop → main PR 을 머지하면 끝. 수동 조작 없음.
```

**Firebase App Distribution 은 자동 트리거를 내려뒀다** — `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` 가 등록돼 있지 않아 main push 마다 실패로 남기 때문이다. 시크릿을 등록하면 `push: branches: ["main"]` 을 되살린다.

## 워크플로우

| 파일 | 하는 일 |
|---|---|
| `PROJECT-COMMON-VERSION-CONTROL` | `version.yml` 의 patch·build number 자동 증가 후 `pubspec.yaml` 동기화 |
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` | PR 병합 시 CHANGELOG 갱신 |
| `PROJECT-COMMON-README-VERSION-UPDATE` | README 버전 배지·표 갱신 |
| `PROJECT-COMMON-SYNC-ISSUE-LABELS` | 이슈 라벨 동기화 |
| `PROJECT-COMMON-QA-ISSUE-CREATION-BOT` | QA 이슈 생성 |
| `PROJECT-COMMON-SUH-ISSUE-HELPER-*` | 이슈 헬퍼 연동 |
| `PROJECT-COMMON-RELEASE-PUBLISH` | main push 시 GitHub Release 발행 (**노트만** — 산출물은 붙이지 않는다) |
| `PROJECT-COMMON-AI-PR-SUMMARY` | PR 요약 생성 |
| `PROJECT-COMMON-SECRET-FILE-UPLOAD` | 시크릿 파일을 서버로 백업 |
| `PROJECT-FLUTTER-CI` | PR·develop push 빌드 검증 (analyze·test·Android 빌드) |
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD` | Play Store 내부 테스트 배포 |
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD` | APK 를 NAS 로 배포 + **GitHub Release 에 APK 첨부** |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT` | TestFlight 배포 |
| `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD` | Firebase 배포 — **자동 트리거 없음** (시크릿 미등록) |
| `PROJECT-FLUTTER-ANDROID-TEST-APK` · `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT` | 이슈 댓글로 요청하는 테스트 빌드 |

> `PROJECT-FLUTTER-IOS-CICD`(iOS 산출물 NAS 배포)는 **삭제했다** (#46). iOS 검증은 TestFlight 로 하며, NAS 에 iOS 빌드를 따로 쌓을 이유가 없다.
>
> `PROJECT-TEMPLATE-INITIALIZER` · `TEMPLATE-UTIL-VERSION-SYNC` · `version_manager.sh` · `template_initializer.sh` 는 **삭제했다** — `project-auto-wizard` 재통합(2026-08-06)으로 `version_manager.py` 체계가 대체했다. `PROJECT-FLUTTER-ANDROID-PR-CI` 도 `PROJECT-FLUTTER-CI` 가 흡수해 삭제했다.

### `WORKFLOW_PAT` 이 없으면 배포가 조용히 안 된다

`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 이 릴리스 PR 을 automerge 할 때 쓰는 토큰이다.

```yaml
GH_TOKEN: ${{ secrets.WORKFLOW_PAT || github.token }}
```

**`GITHUB_TOKEN` 으로 한 머지는 후속 워크플로우를 트리거하지 않는다** (GitHub 정책 — 워크플로우 무한 루프 방지). 이게 없으면 main 에 머지는 되는데 버전 증가도 배포도 아무것도 돌지 않고, **에러 없이 조용히 아무 일도 일어나지 않는다.**

`repo` · `workflow` 스코프만 있으면 된다. 없으면 main push 후 배포 워크플로우를 손으로 `workflow_dispatch` 해야 한다.

### APK 는 Release 에 붙는다

`RELEASE-PUBLISH` 는 노트만 만든다. 워크플로우 아티팩트는 **1일 뒤 사라지고 로그인해야 받을 수 있어** 실기기 설치용으로 못 쓴다.

그래서 `SYNOLOGY-CICD` 가 APK 빌드 직후 릴리스에 첨부한다. 두 워크플로우가 main push 로 동시에 시작하므로 릴리스가 생길 때까지 기다렸다가 붙이고, 끝내 없으면 경고만 남기고 배포를 막지 않는다.

```
v1.2.41  →  EarLocAlert-v1.2.41-90589ba.apk
```

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

## 실제로 깨져 있던 것들 (2026-08-03 v1.2.23 배포에서 발견)

**"CI/CD 완비"는 사실이 아니었다.** 첫 실제 배포에서 파이프라인 4개 중 2개가 실패했고, PR CI 도 Android 빌드가 한 번도 성공한 적 없는 상태였다.

| 결함 | 원인 | 조치 |
|---|---|---|
| PR CI Android 빌드 불가 | `android/.gitignore` 가 gradle wrapper 를 제외해 `gradlew` 가 없었다 | wrapper 커밋 + `.gitattributes` 로 LF 고정 (#43) |
| PR CI 가 테스트를 안 돌림 | `analyze`·`build` 만 있고 `flutter test` 가 없었다 | `build_runner` + `flutter test` 단계 추가 (#43) |
| Android Synology 배포 실패 | `fastlane build` 호출 — 그런데 `android/fastlane/` 에 `Fastfile` 이 없고 `build` lane 도 없다 | fastlane 제거, `flutter build apk` 직접 호출 (#46) |
| iOS TestFlight 실패 | `Xcode 16.3` 고정 → 기본 SDK iOS 18.4 가 러너에 미설치 | Xcode 선택을 방어적으로 변경 + 플랫폼 확인/설치 (#46) |
| `PROJECT_NAME: "your-project"` | 템플릿 기본값 잔존. APK 파일명·NAS 경로·이력 파일명에 실제 사용됨 | `EarLocAlert` 로 교체 (#46) |

> **교훈** — 배포 파이프라인은 실제로 끝까지 돌려보기 전까지 "된다"고 말할 수 없다. 워크플로우 파일이 존재하는 것과 그것이 성공하는 것은 다른 문제다.

### Xcode 버전을 고정하지 않는 이유

GitHub 러너 이미지는 예고 없이 갱신된다. 특정 Xcode 버전을 하드코딩하면 이미지가 바뀔 때마다 같은 실패가 반복된다.

현재는 지정 버전이 있으면 쓰고 없으면 러너 기본값으로 폴백하며, 선택한 Xcode 에 iOS 플랫폼이 없으면 `xcodebuild -downloadPlatform iOS` 로 설치를 시도한다.

## 릴리스가 조용히 누락된다 (2026-08-14 v1.6.0 에서 발견)

**워크플로우가 전부 초록불인데 태그도 릴리스도 안 만들어졌다.** v1.6.0 은 main 에 머지됐고 `version.yml` 도 1.6.0 인데 GitHub 릴리스가 v1.5.0 에서 멈춰 있어 **APK 를 받을 수 없었다.**

### 원인 — 게이트 판정과 버전 커밋의 경합

`PROJECT-COMMON-RELEASE-PUBLISH.yaml` 은 릴리스 여부를 이렇게 판정한다.

```yaml
HEAD_MSG=$(git log -1 --pretty=%B)
...
elif printf '%s\n' "$HEAD_MSG" | grep -q "chore(release):"; then
  PROCEED=true
```

`pr-flow` 모드에서는 **체크아웃된 HEAD 의 커밋 메시지에 `chore(release):` 가 있어야** 릴리스를 만든다. 그런데 main push 로 여러 워크플로우가 동시에 시작하고, `VERSION-CONTROL` 이 먼저 `chore(version): confirm vX.Y.Z ... [skip ci]` 커밋을 main 에 push 하면 RELEASE-PUBLISH 의 체크아웃이 **그 커밋을 잡는다.** 거기엔 `chore(release):` 가 없으므로 게이트가 닫히고, 로그에 이렇게 남는다.

```
not a release-confirm push in pr-flow mode — skipping
```

**둘의 순서가 실행마다 달라지므로 간헐적으로 누락된다.** v1.5.0 은 통과했고 v1.6.0 은 실패했다.

### 드리프트 가드도 못 잡았다

이 상황을 잡으라고 있는 가드가 있다.

```
drift guard ok (version.yml=1.6.0, latest tag=v2.1.3)
```

`git tag --list 'v*' --sort=-v:refname | head -n 1` 로 최신 태그를 고르는데, 이 저장소에 **`v2.1.3` 태그가 있다.** 이 앱의 버전 체계와 무관한 태그(템플릿 통합 잔재로 추정)가 최신으로 잡혀 "version.yml 이 태그보다 앞서지 않는다"고 오판했다. 경고조차 뜨지 않은 이유다.

### 복구 방법

`workflow_dispatch` 는 게이트를 우회한다 (`EVENT = workflow_dispatch` → `PROCEED=true`).

```
Actions → PROJECT-RELEASE-PUBLISH → Run workflow (ref: main)
```

API 로도 된다.

```bash
curl -X POST -H "Authorization: Bearer $PAT" \
  https://api.github.com/repos/Cassiiopeia/EarLocAlert/actions/workflows/PROJECT-COMMON-RELEASE-PUBLISH.yaml/dispatches \
  -d '{"ref":"main"}'
```

### 근본 해결은 템플릿 쪽이다

워크플로우는 projectops 템플릿이 관리하므로 이 저장소에서 고치면 다음 템플릿 갱신에 덮인다. 상류에서 고쳐야 한다 — 게이트를 커밋 메시지가 아니라 **`version.yml` 과 최신 태그의 비교**로 판정하면 순서와 무관해진다.

**당장 할 수 있는 것**: 배포 후 릴리스가 생겼는지 확인하고, 없으면 위 방법으로 재발행한다. `v2.1.3` 태그도 정리 대상이다.

### 곁들여 발견 — automerge 가 실패해도 PR 은 깨끗하다

같은 날 PR #99 에서 `RELEASE-CHANGELOG` 의 **Enable automerge** 단계가 실패했다.

```
##[error]PR merge failed (allow_merge_commit=true) — check branch protection rules, required checks, and token permissions
```

그런데 PR 자체는 `mergeable: true`·`mergeable_state: clean` 이었고 버전 커밋(`chore(version): confirm v1.7.0`)도 이미 develop 에 올라가 있었다. **머지 API 호출만 실패한 것**이라 수동 머지로 그대로 진행됐다.

수동 머지할 때 **제목을 반드시 `chore(release): vX.Y.Z (PR #N)` 형식으로** 준다. 릴리스 게이트가 merge commit subject 를 보기 때문에, 제목이 다르면 위와 같은 릴리스 누락이 또 일어난다.

```bash
# /pro-github 의 merge-pr 사용
merge-pr {owner} {repo} {PR} --method merge --title "chore(release): v1.7.0 (PR #99)"
```

**배포는 PR 을 올린 것으로 끝나지 않는다.** 머지·태그·릴리스·APK 첨부까지 확인해야 "배포됐다"고 말할 수 있다.

## 남은 정리 대상

### ~~시크릿 이름이 워크플로우마다 다르다~~ — 통일 완료 (2026-08-04)

**이 문서는 "둘 다 등록해두면 동작은 한다"고 적고 있었지만 사실이 아니었다.** 실제로 등록된 것은 한쪽뿐이었다.

| 워크플로우가 부르던 이름 | 등록 여부 |
|---|---|
| `ENV_FILE` · `RELEASE_*` | 있음 |
| `ENV` · `KEYSTORE_FILE` · `KEYSTORE_PASSWORD` · `KEY_ALIAS` · `KEY_PASSWORD` | **없음** |
| `SECRETS_XCCONFIG` · `GOOGLE_SERVICES_JSON` | **없음** |

그래서 **PR CI 는 계속 빈 `.env` 를 만들고 있었다.** `.env` 를 읽는 코드가 없어서 드러나지 않다가, Maps 키를 `.env` 에서 읽게 되면서 문제가 됐다.

실제로 존재하는 이름(`ENV_FILE`·`RELEASE_*`)으로 통일했다. 없는 쪽으로 맞추면 새 시크릿을 만들 때까지 전부 깨지지만, 있는 쪽으로 맞추면 즉시 정상 동작한다.

죽은 단계 두 개도 제거했다.

- `SECRETS_XCCONFIG` — 파일을 만들기만 하고 어느 xcconfig 에서도 include 하지 않아 효과가 없었다
- `GOOGLE_SERVICES_JSON` — 이 앱은 Firebase 를 쓰지 않는다

> **교훈** — "둘 다 등록해두면 된다"는 문장은 확인 없이 쓰였다. 시크릿은 `gh secret list` 로 실물을 대조한다.

---

## 시크릿

### Android

| 시크릿 | 용도 |
|---|---|
| `RELEASE_KEYSTORE_BASE64` | 앱 서명 키스토어 |
| `RELEASE_KEYSTORE_PASSWORD` · `RELEASE_KEY_ALIAS` · `RELEASE_KEY_PASSWORD` | 키스토어 접근 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` | Play Console 업로드 |
| `ENV_FILE` | 앱 런타임 환경 변수 (`.env` 본문) |
| `MAPS_API_KEY` | Google Maps 키. `.env` 에 덧붙는다 |

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
| `ENV_FILE` | 앱 런타임 환경 변수 (`.env` 본문) |
| `MAPS_API_KEY` | Google Maps 키. `.env` 에 덧붙는다 |

인증서와 프로비저닝 프로필은 **만료된다.** 만료 시점을 알기 어려운데, 빌드가 갑자기 실패하면 여기를 먼저 본다.

> **2026-08-03 현재 만료 상태다.** 프로비저닝 프로필이 **2026-07-21 에 만료**되었고, `iOS Distribution` 인증서도 팀 ID `CUK22HY6YC` 로 매칭되지 않는다. iOS 빌드가 아카이브 단계에서 실패한다 (#46).
>
> ```
> error: Provisioning profile "..." expired on Jul 21, 2026.
> error: No signing certificate "iOS Distribution" found
> ```
>
> **코드로 해결할 수 없다.** Apple Developer 계정에서 갱신한 뒤 `APPLE_CERTIFICATE_BASE64` · `APPLE_PROVISIONING_PROFILE_BASE64` · `IOS_PROVISIONING_PROFILE_NAME` 시크릿을 교체해야 한다.

### 만료를 미리 알 수 있게 한다

이번에도 "빌드가 갑자기 깨져서" 알았다. 프로필은 보통 1년이라 잊고 지내다 배포 직전에 막힌다.

TestFlight 워크플로우에 만료일 검사 단계를 넣어, 만료 30일 전부터 경고를 출력하는 것을 검토한다 → [11-ROADMAP](11-ROADMAP.md)

---

## 앱이 필요로 하는 키

| 키 | 쓰는 곳 | 주의 |
|---|---|---|
| Google Maps API 키 | `.env` → 네이티브 빌드 | **패키지명·번들 ID 로 제한한다** |
| AdMob 앱 ID | 매니페스트 · plist | 공개 정보 — 숨길 필요 없다 |
| AdMob 광고 단위 ID | 코드 | 빌드 종류로 자동 분기 |

### Maps API 키 — 단일 소스는 `.env` 다

키는 **Dart 런타임 값이 아니라 네이티브 빌드 시점 값**이다. `flutter_dotenv` 로 읽어서 쓰는 게 아니라, 빌드가 매니페스트·plist 에 박아 넣는다.

```
.env  (MAPS_API_KEY=AIza…, gitignore 됨)
  │
  ├─ Android  build.gradle.kts 가 .env 파싱
  │           → manifestPlaceholders → AndroidManifest 의 ${MAPS_API_KEY}
  │
  └─ iOS      tool/sync_env.sh → ios/Flutter/MapsKey.xcconfig
              → Info.plist 의 MapsApiKey → AppDelegate → GMSServices
```

**키가 없어도 빌드는 성공한다.** 지도만 회색으로 뜨고 나머지 기능은 정상 동작한다 — 키 없는 사람도 레포를 받아 빌드할 수 있어야 한다. iOS 는 빈 키를 SDK 에 넘기면 앱이 죽으므로 `AppDelegate` 가 빈 값이면 초기화를 건너뛴다.

로컬 준비는 `cp .env.example .env` 후 값 채우기. iOS 빌드 전에는 `./tool/sync_env.sh` 를 한 번 돌린다.

CI 에서는 **`MAPS_API_KEY` 를 별도 시크릿으로 두고** 각 워크플로우가 `.env` 에 덧붙인다.

```yaml
printf "%s\n" "${{ secrets.ENV_FILE }}" > .env
echo "MAPS_API_KEY=${{ secrets.MAPS_API_KEY }}" >> .env
```

**`ENV_FILE` 본문에 넣지 않는 이유**는 시크릿을 읽을 수 없기 때문이다. GitHub 시크릿은 쓰기 전용이라, 한 줄을 추가하려면 전체를 다시 써야 하고 그 과정에서 기존 값이 날아갈 수 있다. 값 하나를 추가할 때는 시크릿을 하나 더 만드는 쪽이 안전하다.

키를 교체할 때는 `gh secret set MAPS_API_KEY` 한 번이면 되고, 워크플로우는 손대지 않는다.

### Maps API 키는 반드시 제한을 건다

APK 를 뜯으면 키가 보인다. **제한을 걸지 않으면 남이 내 키로 API 를 호출하고 과금이 나에게 온다.**

- API 제한: `Maps SDK for Android` · `Maps SDK for iOS` 만
- Android 앱 제한: 패키지명 `kr.suhsaechan.ear_loc_alert` + SHA-1 인증서 지문
- iOS 앱 제한: 번들 ID `kr.suhsaechan.earlocAlert`
- 사용량 상한(quota) 설정

**앱 제한은 서명 키스토어가 있어야 SHA-1 을 뽑을 수 있다.** 발급 직후에는 API 제한만 걸고, 실기기 릴리스 빌드를 만들 때 앱 제한을 추가한다.

```bash
# 디버그 키스토어 SHA-1
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android -keypass android | grep SHA1
```

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
