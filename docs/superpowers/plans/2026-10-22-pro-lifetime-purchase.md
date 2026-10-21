# 프로 평생 이용권 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android 에서 일회성 상품 `pro_unlock`(평생 이용권)을 팔고, 무료/프로 경계(장소 1개·기본 알림음·백업 불가·광고)를 앱 전체에 적용한다.

**Architecture:** 등급 판단은 `core/entitlement` 한 곳(플랫폼 + 보유 상태 → `FeatureAccess`)에 두고 places·sounds·settings·ads 는 그 값만 읽는다. 결제·기존 사용자 판정·프로 UI 는 새 feature `features/pro`, 진입점 배선은 `app` 계층(라우트·조율자)이 한다. feature 끼리 import 하지 않는다.

**Tech Stack:** Flutter 3.35.5, Riverpod codegen, `in_app_purchase`, SharedPreferences, Drift(기존).

**Spec:** `docs/superpowers/specs/2026-10-21-pro-lifetime-purchase-design.md` · 이슈 #294

## Global Constraints

- 상품 ID `pro_unlock`. 가격은 코드에 박지 않고 `ProductDetails.price` 를 쓴다.
- 상한: 무료 1 / Android 프로 30 / iOS 20(등급 없음). 표기는 프로 "제한 없음".
- iOS: 결제·칩·카드·블러 전부 숨김, 전 기능 열림, 광고 유지. 기존 사용자 판정만 실행·기록.
- 알림 해제는 광고·결제와 무관하게 즉시 완료(규칙 4). 알림 화면·해제 직후·온보딩에 결제 UI 금지.
- 오프라인·조회 실패 시 마지막 상태 유지. pending 은 프로 아님. 구매 성공 시 `completePurchase` 필수.
- 환불 후 무료: 기존 장소·알림음은 계속 동작(감시 동기화는 플랫폼 상한만 적용), 추가·다른 음으로 변경·내 음원 등록만 차단.
- 문구: 네 언어 arb(ko·en·ja·zh). ko 확정 문구 — 시트 제목 `평생 이용권`, 부제 `구독 아님 · 기기 바꿔도 같은 계정이면 유지`, 버튼 `평생 이용권 {price}`, 복원 `이미 구매했나요? 복원하기`, 블러 버튼 `평생 이용권으로 열기`, 기기 한도 `기기 한도에 도달했어요`, 카드 제목 `장소를 제한 없이 등록하세요`, 카드 부제 `알림음 전체 · 장소 백업 · 광고 없음`, 사용량 `장소 {count}/{limit} 사용 중`, 기존 사용자 `기존 사용자 혜택`.
- 색·간격·글자는 토큰(`context.appColors`, `context.appTextStyles`, `AppSpacing`)만. 로그는 `Diagnostics.log('pro', ...)` 영어 `[tag] event key=value`.
- 자동 테스트 없음(결정 070). 각 태스크 검증 = `flutter analyze` 통과 + 마지막에 Android 빌드·에뮬레이터 확인.
- Flutter: `export PATH="$HOME/development/flutter-3.35.5/bin:$PATH"`. codegen: `dart run build_runner build --delete-conflicting-outputs`.

## Review Focus

- 환불(구매 사라짐) 감지 시 장소 2개 이상 보유 사용자 — 기존 장소 전부 계속 감시되는가(동기화가 등급 상한으로 자르면 안 됨). Task 2 에서 동기화는 `PlaceLimits.platformMaximum` 만 쓰는지 리뷰.
- 앱 시작 시 Play 연결 실패·상품 없음(콘솔 미등록) — 프로 상태 유지, 시트 구매 버튼 비활성 + 사유. Task 4·6.
- 구매 흐름 중 앱 재시작(구매 스트림이 다음 실행에 도착) — 시작 시 리스너가 먼저 붙어 처리·`completePurchase`. Task 4.
- 기존 사용자 판정이 장소 저장소 읽기 전에 돌아 0개로 오판 — 판정은 `findAll()` 결과로 1회. Task 5.
- 무료 사용자가 백업 "가져오기"를 우회(딥링크 없음)하거나 알림음 시트에서 잠긴 음을 기존 값으로 들고 있는 경우 — 시트가 현재 값을 유지해 돌려주는지. Task 7.

---

### Task 1: core 등급 판단 (`core/entitlement`)

**Files:**
- Create: `lib/core/entitlement/place_limits.dart`
- Create: `lib/core/entitlement/pro_entitlement.dart`
- Create: `lib/core/entitlement/feature_access.dart`
- Create: `lib/core/entitlement/feature_access_controller.dart`

**Interfaces:**
- Produces:
  - `abstract final class PlaceLimits { static const int freePlaces = 1; static const int androidProPlaces = 30; static const int iosPlaces = 20; static int platformMaximum() }` — `Platform.isAndroid ? 30 : 20`. 백그라운드 isolate 에서도 호출 가능(Flutter 바인딩 불필요).
  - `enum ProEntitlementSource { none, purchase, legacyUser }` + `String storageValue` / `static ProEntitlementSource fromStorage(String?)`.
  - `class ProEntitlementStore` (SharedPreferences): `Future<ProEntitlementSource> read()`, `Future<void> write(ProEntitlementSource)`, `Future<bool> isLegacyCheckDone()`, `Future<void> markLegacyCheckDone()`. 키: `pro_entitlement_source`, `pro_legacy_check_done`.
  - `class FeatureAccess { const FeatureAccess({required bool isPaywallEnabled, required ProEntitlementSource source}); bool get isPro; int get placeLimit; bool get canUseAllSounds; bool get canUsePlaceBackup; bool get shouldShowAds; bool isPlaceAddLocked(int placeCount); bool isAtDeviceLimit(int placeCount); }`
    - `isPaywallEnabled == false`(iOS) → placeLimit `platformMaximum()`, 나머지 전부 열림, `isPlaceAddLocked` 항상 false.
    - 프로 → placeLimit `platformMaximum()`, 열림, 광고 없음.
    - 무료 → placeLimit 1, 잠김, 광고 있음.
    - `isAtDeviceLimit(count)` = `!isPlaceAddLocked(count) && count >= platformMaximum()`.
  - `@Riverpod(keepAlive: true) ProEntitlementSource proEntitlementInitial(Ref)` (main 이 override), `@Riverpod(keepAlive: true) class FeatureAccessController` — `FeatureAccess build()`; `Future<void> setSource(ProEntitlementSource next, {required String reason})` (상태 갱신 + 저장 + 로그 `[pro] entitlement changed from= to= reason=`).

- [ ] **Step 1:** 위 4개 파일 작성. `isPaywallEnabled` 는 `Platform.isAndroid`.
- [ ] **Step 2:** `lib/main.dart` 에서 `await const ProEntitlementStore().read()` 후 `proEntitlementInitialProvider.overrideWithValue(...)`.
- [ ] **Step 3:** build_runner → `flutter analyze` 무오류.

### Task 2: 장소 상한을 `FeatureAccess`/`PlaceLimits` 로 교체

**Files:**
- Modify: `lib/features/places/domain/place_validator.dart` — `maxPlaces` 상수 제거, `validate(... required int maxPlaces)` 인자로 받음.
- Modify: `lib/features/places/presentation/place_list_controller.dart:47` — `ref.read(featureAccessControllerProvider).placeLimit` 전달.
- Modify: `lib/features/places/domain/place_backup.dart:218` — `plan(... required int maxPlaces)`.
- Modify: `lib/features/places/presentation/place_backup_actions.dart` — `importPlacesBackup(..., required int maxPlaces)` 받아 plan 에 전달.
- Modify: `lib/app/geofence_registration_sync.dart:28`, `lib/app/background/watch_engine_entrypoint.dart:144` — `PlaceLimits.platformMaximum()` (등급 아님).
- Modify: `lib/features/places/presentation/place_empty_state.dart:79` — limitReached 문구에 상한 값 인자 전달 구조 유지, 호출부가 limit 를 넘긴다.

- [ ] **Step 1:** 수정. `limitReached` 문구 매핑 함수는 `limit` 인자를 받는다.
- [ ] **Step 2:** `grep -rn "maxPlaces" lib` 로 잔여 참조 0 확인(인자 이름 제외), `flutter analyze` 무오류.

### Task 3: 블러 잠금 공통 컴포넌트 + 문구

**Files:**
- Create: `lib/core/ui/components/locked_content_blur.dart`
- Modify: `lib/core/l10n/arb/app_{ko,en,ja,zh}.arb`

**Interfaces:**
- Produces: `class LockedContentBlur extends StatelessWidget { const LockedContentBlur({required Widget child, required String caption, required String actionLabel, required VoidCallback onUnlock}) }` — `ImageFiltered(ImageFilter.blur(sigma 4))` + `IgnorePointer` + 반투명 덮개, 가운데 caption 텍스트와 `FilledButton`(accent). 영역 전체 탭 → `onUnlock`. 자물쇠 아이콘 없음.
- l10n 키(ko 값은 Global Constraints): `proSheetTitle`, `proSheetSubtitle`, `proSheetBuy(price)`, `proSheetRestore`, `proSheetCompareFree`, `proSheetComparePro`, `proRowPlaces`, `proRowDirections`, `proRowSchedules`, `proRowVibration`, `proRowSound`, `proRowBackup`, `proRowAds`, `proValueOnePlace`(`1개`), `proValueUnlimited`(`제한 없음`), `proValueDefaultSound`(`기본 1개`), `proValueAllSounds`(`전체 + 내 음원`), `proValueAdsOn`(`있음`), `proValueAdsOff`(`없음`), `proUnlockAction`, `proLockedSounds`(`알림음 전체 · 내 음원`), `proLockedPlaces`(`장소를 더 등록하려면`), `proLockedBackup`(`장소 백업 · 가져오기`), `proLockedExamplePlaceHome`(`집`), `proLockedExamplePlaceStation`(`역`), `proCardTitle`, `proCardSubtitle`, `proCardUsage(count, limit)`, `proCardBuy(price)`, `proRowLifetime`(`평생 이용권`), `proLegacyBadge`, `proDeviceLimitReached`, `proProductUnavailable`(`지금은 구매할 수 없어요. 잠시 뒤 다시 시도해 주세요`), `proPurchasePending`(`결제가 확인되면 열려요`), `proPurchaseDone`(`평생 이용권이 열렸어요`), `proPurchaseFailed`(`결제를 마치지 못했어요`), `proRestoreNone`(`복원할 구매가 없어요`), `proRestoreDone`(`구매를 복원했어요`), `proChipFree`(`FREE`), `proChipPro`(`PRO`).

- [ ] **Step 1:** 컴포넌트·arb 작성 → `flutter gen-l10n`(또는 build) → `flutter analyze`.

### Task 4: Play 결제 어댑터 (`features/pro/data`)

**Files:**
- Modify: `pubspec.yaml` — `in_app_purchase` 추가(3.35.5 호환 최신, 주석으로 이유).
- Create: `lib/features/pro/domain/pro_purchase_service.dart`
- Create: `lib/features/pro/data/play_pro_purchase_service.dart`
- Create: `lib/features/pro/data/pro_purchase_providers.dart`

**Interfaces:**
- Produces:
  - `sealed class ProPurchaseEvent` — `ProPurchased`, `ProPurchasePending`, `ProPurchaseFailed(String reason)`, `ProPurchaseCancelled`, `ProRestored`.
  - `abstract interface class ProPurchaseService { Stream<ProPurchaseEvent> get events; Future<String?> loadPrice(); Future<bool> buy(); Future<void> restore(); Future<bool?> hasOwnedPurchase(); void dispose(); }`
    - `loadPrice` null = 상품 못 읽음. `hasOwnedPurchase` null = 조회 실패(상태 유지 신호).
  - `PlayProPurchaseService implements ProPurchaseService` — `InAppPurchase.instance`. `purchaseStream` 에서 `productID == 'pro_unlock'` 만: purchased/restored → `completePurchase`(pendingCompletePurchase 일 때) 후 이벤트, pending → 대기, error/canceled → 실패/취소. `hasOwnedPurchase` 는 `InAppPurchaseAndroidPlatformAddition.queryPastPurchases()` 로 소유 여부.
  - `@Riverpod(keepAlive: true) ProPurchaseService proPurchaseService(Ref)` — Android 아니면 아무것도 안 하는 `NoopProPurchaseService`.
- 모든 분기 `[pro]` 로그(상품 조회 결과, 구매 시작·결과, 복원 결과, 조회 실패 사유).

- [ ] **Step 1:** pub add → 파일 작성 → build_runner → analyze.

### Task 5: 시작 조율 — 기존 사용자 판정·구매 반영 (`app/pro_access_coordinator.dart`)

**Files:**
- Create: `lib/app/pro_access_coordinator.dart`
- Modify: `lib/app/app.dart` — 앱 시작 시 `start()` 1회.

**Interfaces:**
- Consumes: `FeatureAccessController.setSource`, `ProEntitlementStore`, `ProPurchaseService`, `PlaceRepository.findAll`.
- Produces: `class ProAccessCoordinator { Future<void> start(); }` + `@Riverpod(keepAlive: true)` provider.
  1. 구매 이벤트 구독(먼저): `ProPurchased|ProRestored` → `setSource(purchase)`.
  2. 기존 사용자 판정(모든 플랫폼, 1회): `isLegacyCheckDone` 아니면 `findAll().length >= 1` 이고 현재 none 이면 `legacyUser` 저장, 판정 완료 기록, 로그 `[pro] legacy check places= granted=`.
  3. Android: `hasOwnedPurchase()` — true → purchase, false 이고 현재 purchase → none(환불, 로그 `reason=refund_detected`), null → 유지(로그 `reason=query_failed`). legacyUser 는 건드리지 않는다.
  예외는 삼키고 로그.

- [ ] **Step 1:** 작성·연결 → analyze.

### Task 6: 프로 UI (`features/pro/presentation`)

**Files:**
- Create: `lib/features/pro/presentation/pro_offer_sheet.dart` — `Future<void> showProOfferSheet(BuildContext, {required String entryPoint})`: 비교표 시트(시안 B), 가격 로드 중/실패 상태, 구매·복원 버튼, 이벤트에 맞춘 토스트, 프로가 되면 닫힘. 로그 `[pro] offer shown entry=`.
- Create: `lib/features/pro/presentation/pro_settings_card.dart` — `ProSettingsCard({required int placeCount})`: 무료면 큰 카드(FREE 칩, `proCardUsage`, 제목·부제, 구매 버튼 → 시트), 프로면 `GroupedListRow` 한 줄(`PRO 평생 이용권`, legacy 면 오른쪽 `proLegacyBadge`, 누르면 복원 시트=같은 시트). iOS 면 `SizedBox.shrink()`.
- Create: `lib/features/pro/presentation/plan_badge_chip.dart` — `PlanBadgeChip()`: 무료 회색 FREE(탭 → 시트), 프로 민트 PRO(탭 없음), iOS 숨김.

- [ ] **Step 1:** 작성 → analyze.

### Task 7: 진입점 배선 (app 라우트 + 화면 인자)

**Files:**
- Modify: `lib/features/places/presentation/place_map_home_screen.dart`, `home/home_status_bar.dart`, `home/home_place_sheet.dart` — 인자 `Widget? planBadge`(상태 줄 설정 버튼 왼쪽), `bool isPlaceAddLocked`, `VoidCallback? onUnlockPro`. 잠김이면 목록 끝에 `LockedContentBlur(caption: proLockedPlaces, child: 예시 장소 2행)`.
- Modify: `lib/app/routes/home_route.dart` — `onAddPlace`: 잠김 → `showProOfferSheet(entryPoint: 'place_add')`, 기기 한도 → 토스트 `proDeviceLimitReached`, 아니면 push. `planBadge: const PlanBadgeChip()`.
- Modify: `lib/features/sounds/presentation/sound_picker_sheet.dart` — `showSoundPickerSheet(..., bool isPremiumSoundLocked = false, VoidCallback? onUnlockPro)`. 잠김이면 `defaultTone` 행만 그대로, 나머지 프리셋 + 내 음원 섹션 + 추가 버튼을 `LockedContentBlur(caption: proLockedSounds)` 로 감싼다. 선택값은 현재 값 유지.
- Modify: `lib/app/routes/place_routes.dart:45` — 잠김 여부·시트 콜백 전달(`entryPoint: 'sound_picker'`).
- Modify: `lib/features/settings/presentation/settings_screen.dart` — 인자 `Widget? planCard`(맨 위), `bool isPlaceBackupLocked`, `VoidCallback? onUnlockPro`; 잠김이면 백업 섹션 rows 를 `LockedContentBlur(caption: proLockedBackup)` 로.
- Modify: `lib/app/routes/settings_route.dart` — `planCard: ProSettingsCard(placeCount: …)`, 잠김·콜백(`entryPoint: 'backup'`), import 에 `maxPlaces: access.placeLimit`.
- Modify: 장소 저장 `limitReached` 처리 — 무료면 문구 대신 시트, 프로면 `proDeviceLimitReached`.

- [ ] **Step 1:** 수정 → analyze.

### Task 8: 프로면 광고 끄기

**Files:**
- Modify: `lib/app/ad_banner_frame.dart` — `ConsumerStatefulWidget` 로, `shouldShowAds == false` 면 child 만(슬롯 생성 안 함 = 요청 없음).
- Modify: `lib/app/alert_ad_coordinator.dart` + provider — `bool Function() shouldShowAds` 주입. `onAlertFired`·`onAlertDismissed` 앞에서 false 면 로그 `[ads] skipped reason=pro` 후 반환. 해제 순서 불변.

- [ ] **Step 1:** 수정 → analyze.

### Task 9: 문서·검증

**Files:**
- Modify: `docs/10-DECISIONS.md`(072 평생 이용권), `docs/07-MONETIZATION.md`(다른 수익 모델 표), `docs/11-ROADMAP.md`(현황 표 + 실기기 결제 확인 항목), `CLAUDE.md` 현재 상태 한 단락.

- [ ] **Step 1:** 문서 작성.
- [ ] **Step 2:** `flutter analyze` 0 issue, `flutter build apk --debug` 성공.
- [ ] **Step 3:** 에뮬레이터: 무료(장소 1개 → 추가 시 시트, 알림음 블러, 설정 카드·백업 블러, 홈 FREE 칩), 디버그 강제 프로 전환(아래) 후 PRO 칩·한 줄·광고 없음 캡처.
  - 검증용 강제 전환: 디버그 빌드에서만 `ProEntitlementStore` 값을 adb 로 바꾸지 않고, 진단 화면 등 UI 추가 없이 `--dart-define=PRO_DEBUG_SOURCE=purchase` 를 디버그에서만 읽어 초기값을 덮는다(`kDebugMode` 가드).
