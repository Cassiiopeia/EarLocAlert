# 프로 평생 이용권 iOS (App Store 비소모성 상품) 설계

작성일: 2026-10-23 · 이슈 #298 · 원 설계: [2026-10-21-pro-lifetime-purchase-design.md](2026-10-21-pro-lifetime-purchase-design.md) (#294)

## 1. 의도

Android 에만 있던 평생 이용권을 iOS 에도 똑같이 판다 (사용자 결정). iOS 사용자도 한 번 결제로 장소 제한 해제·알림음 전체·백업·광고 제거를 얻는다.

## 2. 목표 · 하지 않는 것

- 목표: Android 와 같은 무료/프로 경계, 같은 결제 화면, 같은 복원·환불 동작.
- 가격 기준 (사용자): **판매 1건당 부가세·수수료 제외 순수익 5,000원 이상.**
- 하지 않는 것: 구독, 로그인, 서버 영수증 검증, iOS 프로모션 코드(지원 여부 미확인).
- 실패 조건(anti-goal): 결제할 수 없는 상태로 iOS 사용자를 무료로 묶는 것. 유료 앱 계약·상품 심사가 끝나기 전에 App Store 에 내보내지 않는다.

## 3. 무료 / 프로 경계

원 설계 3장과 같다. iOS 프로 장소 상한은 OS 영역 감시 한도 **20**(화면 표기 "제한 없음"). 감시 상한은 등급과 무관해, 업데이트 후 무료가 된 기존 사용자의 장소도 계속 울린다.

## 4. 결제 흐름 (StoreKit 2, `in_app_purchase` 플러그인)

| 동작 | 방법 |
|---|---|
| 가격 | `queryProductDetails({'pro_unlock'})` 의 현지화 가격 문자열. 못 읽으면 구매 버튼 비활성 |
| 구매 | `buyNonConsumable`. 결과는 구매 스트림. 이미 산 계정은 결제 없이 구매 거래가 다시 옴 |
| 완료 처리 | 상태와 무관하게 `pendingCompletePurchase` 면 `completePurchase`(finish). 안 하면 실행마다 다시 옴 |
| 보유 조회 | `restorePurchases` = `Transaction.currentEntitlements` — **로그인 창 없음**, 환불된 구매 제외. 조회 중 도착한 복원 거래는 결과로만 쓰고 이벤트로 보내지 않음 |
| 대기 | Ask to Buy 등 `pending` > 프로로 열지 않음 |
| 구매 기록 | 거래 ID(주문 번호 자리), 구매 시각(`yyyy-MM-dd HH:mm:ss` 기기 시간대 > UTC) |

`AppStore.sync()` 는 로그인 창을 띄우므로 쓰지 않는다.

## 5. 구조

- `ProPurchaseService` 에 `store`(googlePlay·appStore·none) 추가 — 화면은 이 값으로 스토어별 요소만 가린다.
  - 프로모션 코드 버튼: Play 만
  - 이용권 정보의 구매 계정 안내: App Store 는 Apple 계정 문구(`proInfoNotePurchaseAppStore`)
- `StoreKitProPurchaseService` (`lib/features/pro/data/`) 신설, 제공자는 Android > Play / iOS > StoreKit / 그 외 > 없음.
- `FeatureAccessController.isPaywallEnabled = Android || iOS`.
- 로그는 `[pro]` 태그로 Play 와 같은 지점(상품 조회, 구매 시작·갱신·실패, 완료 처리, 보유 조회 결과).

## 6. 출시 전 사용자 작업

1. App Store Connect 법인 정보 업데이트(사업자등록증 기준) > **유료 앱 계약 서명**
2. 소규모 사업자 프로그램 신청 여부 결정 — 15% 면 ₩6,500(약 5,023원), 30% 면 약 ₩7,900 이상
3. 비소모성 상품 `pro_unlock` 생성 · 가격 지정 · 심사 정보(스크린샷) 입력
4. 이 기능이 든 **새 앱 버전과 함께** 상품을 심사 제출
5. 샌드박스 테스터 실기기 확인: 구매, 재설치 후 복원, 환불, Ask to Buy

## 7. 검증

자동 테스트는 레포에 없다(결정 070). `flutter analyze`, iOS 빌드, 그리고 샌드박스 실기기 확인으로 닫는다.
