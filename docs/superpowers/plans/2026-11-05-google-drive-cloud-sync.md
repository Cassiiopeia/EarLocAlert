# Google Drive 클라우드 동기화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 프로 사용자가 구글 계정으로 연결하면 장소가 Drive appDataFolder 에 동기화되고, 재설치·다른 기기(다른 OS 포함)에서 같은 계정으로 연결하면 장소가 돌아온다.

**Architecture:** 병합·변경 감지는 `features/places/domain` 의 순수 Dart. Drive·로그인은 `features/places/data` 의 구현체(`google_sign_in` + `googleapis` Drive v3, 네이티브 채널 없음). `app/cloud_sync_coordinator.dart` 가 장소 변화·앱 전면 진입에 맞춰 읽기 > 병합 > 적용 > 쓰기를 돈다. 장소 테이블은 건드리지 않고 동기화 메타(장소별 내용 서명·수정 시각·삭제 표시)는 prefs 장부에 둔다.

**Tech Stack:** Flutter 3.35.5 / Dart 3.9, Riverpod codegen, Drift(변경 없음), `google_sign_in ^6.2.2`, `googleapis ^14.0.0`, `http ^1.2.2`, shared_preferences.

**Spec:** `docs/superpowers/specs/2026-11-05-google-drive-cloud-sync-design.md`

## Global Constraints

- 저장 위치 Drive **appDataFolder**, 범위 `https://www.googleapis.com/auth/drive.appdata` 하나만
- 파일 이름 `earlocalert-sync.json`, `format: "earlocalert-sync"`, `schemaVersion: 1`
- **전부 프로** (연결·가져오기·동기화). 판정은 `FeatureAccess.canUseCloudSync` 한 곳
- 장소 0개면 절대 업로드하지 않는다. 연결 직후·설치 후 첫 동기화는 읽기 먼저
- 삭제 표시는 90일 지나면 지운다
- 병합 결과는 `PlaceLimits.platformMaximum()` 을 넘지 않는다 (최근 수정 순으로 자름)
- 동기화 실패는 알림 판정·발화에 영향을 주지 않는다 (예외 삼키고 `[sync]` 로그)
- 로그는 `Diagnostics.log('sync', ...)` 영어 `[tag] event key=value`. 계정은 도메인만 (`account=gmail.com`)
- 화면 문자열은 4개 언어 arb. 색·간격은 토큰. 시트는 `showAppBottomSheet` + `BottomSheetWithHeaderLayout`
- 가져온 장소는 `PlaceRepository.save` 경로 (지오펜스 재등록이 따라옴). 상태는 `unknown` 시작 (기존 규칙)
- 사용자 음원(`custom:`)은 기본음으로 바꿔 적는다 (`PlaceBackup` 과 같은 규칙)
- 화면 부팅·온보딩을 로그인으로 막지 않는다

## Review Focus

1. 재설치 직후 장부가 비어 있고 로컬 장소 0개인데 원격에 장소가 있음 → 업로드 없이 가져오기 시트 (Task 2 테스트)
2. 기기 A 에서 지운 장소가 기기 B 의 옛 사본 때문에 되살아남 → 삭제 시각이 수정보다 늦으면 삭제 유지 (Task 2 테스트)
3. 오프라인·토큰 만료로 읽기 실패 → 쓰기도 하지 않음 (읽지 못한 채 덮어쓰기 금지) (Task 5 테스트)
4. 원격 파일이 더 새 `schemaVersion` → 병합·쓰기 모두 중단하고 `reason=newer_schema` (Task 1 테스트)
5. 병합 결과가 상한을 넘음 → 최근 수정 순 상한 개수만, 잘린 수 반환 (Task 2 테스트)

---

### Task 1: 동기화 문서 모양 (인코딩·디코딩)

**Files:**
- Create: `lib/features/places/domain/cloud_sync_document.dart`
- Modify: `lib/features/places/domain/place_backup.dart` (장소 한 건 변환을 공개 함수로)
- Test: `test/critical/cloud_sync_document_test.dart`

**Interfaces:**
- Produces:
  - `PlaceBackup.encodePlace(AlertPlace) -> Map<String, Object?>` (지금 `encode` 루프 본문 추출, `encode` 가 이것을 씀)
  - `PlaceBackup.decodePlace(Object? item, {required String id, required DateTime createdAt}) -> AlertPlace?` (지금 `_decodePlace` 를 id·createdAt 을 받게; `decode` 는 새 id 로 호출)
  - `class CloudSyncEntry { String syncId; DateTime updatedAt; bool isDeleted; AlertPlace? place; }` (삭제면 place null)
  - `class CloudSyncDocument { DateTime updatedAt; String deviceLabel; List<CloudSyncEntry> entries; String toJson(); static CloudSyncDecoded fromJson(String raw); }`
  - `sealed CloudSyncDecoded`: `ok(CloudSyncDocument)`, `failure(CloudSyncDecodeError)`; `enum CloudSyncDecodeError { notJson, notSyncFile, newerSchema }`

- [ ] **Step 1: 실패 테스트** — `encode then decode keeps syncId updatedAt deleted and place fields`, `custom sound is written as fallback`, `newer schemaVersion fails with newerSchema`, `other format fails with notSyncFile`, `invalid place entry is dropped not fatal`
- [ ] **Step 2:** `flutter test test/critical/cloud_sync_document_test.dart` → FAIL (파일 없음)
- [ ] **Step 3:** 구현. `PlaceBackup` 추출 후 기존 동작 유지 (`decode` 결과 동일)
- [ ] **Step 4:** 같은 명령 PASS, `flutter analyze` 0건
- [ ] **Step 5:** 커밋 (`/pro-commit`)

### Task 2: 병합 규칙과 변경 장부

**Files:**
- Create: `lib/features/places/domain/cloud_sync_merge.dart`
- Test: `test/critical/cloud_sync_merge_test.dart`

**Interfaces:**
- Consumes: Task 1 `CloudSyncEntry`, `CloudSyncDocument`, `PlaceBackup.encodePlace`
- Produces:
  - `class SyncLedgerEntry { String syncId; String signature; DateTime updatedAt; bool isDeleted; }`
  - `List<SyncLedgerEntry> CloudSyncMerge.trackLocal({required List<AlertPlace> places, required List<SyncLedgerEntry> previous, required DateTime nowUtc})` — 서명(`jsonEncode(encodePlace)`)이 바뀐 장소는 updatedAt=now, 장부엔 있는데 목록에 없는 장소는 삭제 표시(now), 90일 지난 삭제 표시 제거
  - `CloudSyncMergeResult CloudSyncMerge.merge({required List<SyncLedgerEntry> local, required List<AlertPlace> localPlaces, required CloudSyncDocument? remote, required int maximumPlaces})`
  - `class CloudSyncMergeResult { List<AlertPlace> toSave; List<String> toDelete; List<CloudSyncEntry> mergedEntries; int droppedOverLimit; bool hasRemoteChanges; bool hasLocalChanges; }`

- [ ] **Step 1: 실패 테스트** (설계 표 그대로):
  - `local only is kept and uploaded` (hasLocalChanges true, toSave 빈 목록)
  - `remote only non deleted is imported` (toSave 1)
  - `both present newer updatedAt wins` (원격이 늦으면 toSave, 로컬이 늦으면 mergedEntries 에 로컬)
  - `local tombstone newer than remote edit deletes` / `remote edit newer than local tombstone revives`
  - `remote tombstone newer than local edit deletes locally` (toDelete 에 id)
  - `tombstones older than 90 days are pruned`
  - `over limit keeps most recently updated and reports dropped count` (maximumPlaces 2, 3개 → dropped 1)
  - `unchanged places keep updatedAt` (trackLocal 두 번 같은 목록 → 시각 그대로)
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS
- [ ] **Step 5:** 커밋

### Task 3: 프로 판정과 장부 저장소

**Files:**
- Modify: `lib/core/entitlement/feature_access.dart` — `bool get canUseCloudSync => _isUnlocked;`
- Create: `lib/features/places/data/prefs_cloud_sync_state_store.dart`
- Create (interface): `lib/features/places/domain/cloud_sync.dart`

**Interfaces:**
- Produces (`cloud_sync.dart`):
  - `abstract interface class CloudSyncAccount { Future<String?> signIn(); Future<String?> signInSilently(); Future<void> signOut(); Future<Map<String, String>?> authHeaders(); }` (반환 문자열 = 이메일)
  - `abstract interface class CloudSyncRemote { Future<CloudSyncRead> read(); Future<bool> write(String json); Future<bool> deleteAll(); }`
  - `sealed CloudSyncRead`: `found(String json)`, `empty()`, `failed(String reason)`
  - `abstract interface class CloudSyncStateStore { Future<List<SyncLedgerEntry>> ledger(); Future<void> saveLedger(List<SyncLedgerEntry>); Future<String?> accountEmail(); Future<void> saveAccountEmail(String?); Future<DateTime?> lastSyncedAtUtc(); Future<void> saveLastSyncedAt(DateTime); Future<bool> hasCompletedFirstRead(); Future<void> markFirstReadDone(); Future<void> clear(); }`
- prefs 키: `cloud_sync_ledger`(JSON), `cloud_sync_account_email`, `cloud_sync_last_synced_at`, `cloud_sync_first_read_done`

- [ ] **Step 1:** 장부 저장·읽기 왕복 테스트 `ledger round trip keeps entries` (`SharedPreferences.setMockInitialValues({})`), `test/critical/cloud_sync_state_store_test.dart`
- [ ] **Step 2–4:** FAIL > 구현 > PASS
- [ ] **Step 5:** 커밋

### Task 4: Google 로그인·Drive 구현체

**Files:**
- Modify: `pubspec.yaml` — `google_sign_in: ^6.2.2`, `googleapis: ^14.0.0`, `http: ^1.2.2` (pub get 으로 실제 해석 버전 확인, 3.35.5 와 충돌 시 호환 최신으로)
- Create: `lib/features/places/data/google_cloud_sync_account.dart` — `GoogleSignIn(scopes: [DriveApi.driveAppdataScope])`
- Create: `lib/features/places/data/google_drive_cloud_sync_remote.dart` — `spaces: 'appDataFolder'`, 파일 `earlocalert-sync.json` 찾기(`q: "name = 'earlocalert-sync.json'"`) > 있으면 `files.update`, 없으면 `files.create(parents: ['appDataFolder'])`. 헤더 붙이는 `http.BaseClient` 하나
- Create: `lib/features/places/data/cloud_sync_providers.dart` (Riverpod: account, remote, stateStore)
- Modify: `ios/Runner/Info.plist` — `GIDClientID`, `CFBundleURLTypes` 에 역순 클라이언트 ID (값은 Task 8 콘솔 작업에서)

- [ ] **Step 1:** `flutter pub get` 성공, `flutter analyze` 0건
- [ ] **Step 2:** 구현체는 자동 테스트 없음 (네트워크). 모든 실패는 `CloudSyncRead.failed(reason)`·`false` 로 돌리고 `[sync]` 로그 (`drive read failed status=… reason=…`)
- [ ] **Step 3:** 커밋

### Task 5: 동기화 조율기

**Files:**
- Create: `lib/app/cloud_sync_coordinator.dart` (+ `.g.dart`)
- Modify: `lib/app/app.dart` — 앱 시작 시 `start()`, resumed 시 `runNow(reason: 'resumed')` (자동 백업 조율기 붙인 자리 옆)
- Test: `test/critical/cloud_sync_coordinator_test.dart` (가짜 account·remote·store·repository)

**Interfaces:**
- Consumes: Task 2 `CloudSyncMerge`, Task 3 인터페이스, `PlaceRepository`, `featureAccessControllerProvider`
- Produces:
  - `Future<CloudSyncOutcome> runNow({required String reason})`
  - `Future<CloudSyncConnectResult> connect()` — signIn > 읽기 > (원격 장소 있고 로컬 0개면 `needsImportConfirm(remoteCount, deviceLabel, updatedAt)` 반환, 저장 안 함) > 아니면 병합·적용·쓰기
  - `Future<CloudSyncOutcome> confirmImport()` / `Future<void> disconnect({required bool deleteRemote})`
  - `enum CloudSyncOutcome { synced, unchanged, notPro, notConnected, readFailed, writeFailed, newerSchema, skippedEmpty }`
- 순서: 프로 확인 > 연결 확인(silent) > trackLocal > **read (실패면 끝, 쓰지 않음)** > merge > 적용(save/delete) > 로컬 0개면 쓰지 않음 > 바뀐 게 있으면 write > 장부·시각 저장. 장소 변화 디바운스 3초 (자동 백업과 같은 값을 상수로 공유하지 말고 각자 둠: 2곳)

- [ ] **Step 1: 실패 테스트**
  - `read failure does not write`
  - `empty local with remote places asks confirm and writes nothing`
  - `not pro returns notPro without network calls`
  - `merge result is applied through repository save and delete`
  - `newer remote schema stops with newerSchema`
- [ ] **Step 2–4:** FAIL > 구현 > PASS
- [ ] **Step 5:** 커밋

### Task 6: 화면 (설정 줄, 동기화 시트, 가져오기 시트)

**Files:**
- Create: `lib/features/places/presentation/cloud_sync_sheet.dart` — 계정, 마지막 동기화, 지금 동기화, 연결 끊기(Drive 데이터 지우기 선택). 아이콘 `Icons.cloud_sync_outlined` 는 자동 백업이 쓰므로 `Icons.cloud_outlined`
- Create: `lib/features/places/presentation/cloud_import_sheet.dart` — "Drive 에 장소 N개가 있어요 (기기, 날짜)" > 가져오기 / 나중에
- Modify: `lib/features/settings/presentation/settings_screen.dart` (백업 섹션에 줄), `lib/app/routes/settings_route.dart` (조율기·프로 게이트 연결, 무료면 `pro_gate` 로 프로 안내)
- Modify: `lib/core/l10n/arb/app_{ko,en,ja,zh}.arb` + gen-l10n
- `test/core/l10n/no_hardcoded_korean_test.dart`·`design_system_test` 통과

- [ ] **Step 1:** 구현 > `flutter gen-l10n` > `flutter analyze` 0건 > `flutter test` 통과
- [ ] **Step 2:** 에뮬레이터(디버그 `PRO_DEBUG_SOURCE=purchase`)에서 라이트·다크 캡처: 설정 줄, 연결 전 시트, 무료일 때 프로 안내
- [ ] **Step 3:** 커밋

### Task 7: 문서·개인정보

**Files:**
- Modify: `docs/10-DECISIONS.md` — 새 항목 "클라우드 동기화는 Google Drive appDataFolder 하나로 (iCloud 아님), 전부 프로"
- Modify: `docs/07-MONETIZATION.md` 프로 목록, `docs/09-RELEASE.md` 데이터 안전·개인정보 항목, `docs/05-PLATFORM.md` 미검증 표(실기기 항목)
- Modify: 프로 혜택(`pro_benefit_list.dart`)·비교표(`pro_offer_sheet.dart`)에 "클라우드 동기화" 한 줄 (두 곳 함께)

- [ ] **Step 1:** 수정 > 커밋

### Task 8: 콘솔 설정 (agent 가 브라우저로, pro-launch)

- Google Cloud 프로젝트(Play·Maps 를 쓰는 기존 프로젝트) > Drive API 사용
- OAuth 동의 화면: 앱 이름, 지원 이메일, 개인정보처리방침 `https://cassiiopeia.github.io/EarLocAlert/privacy.html`, 범위 `drive.appdata`. **검증 필요 여부를 콘솔에서 확인해 사용자에게 보고** (필요하면 여기서 멈추고 묻는다)
- OAuth 클라이언트: Android (`kr.suhsaechan.ear_loc_alert` + 디버그·업로드·Play 앱 서명 SHA-1), iOS (번들 ID). iOS 클라이언트 ID 를 Task 4 의 Info.plist 에
- 검증: 에뮬레이터에서 연결 > 장소 등록 > 앱 삭제·재설치 > 연결 > 가져오기 시트 > 복원 (`[sync]` 로그로 확인)

## 하지 않는 것

실시간 푸시, iCloud, 음원 파일·도착 기록·설정 동기화, 백그라운드 isolate 에서의 동기화.
