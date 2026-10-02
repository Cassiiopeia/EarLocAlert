import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/config/dev_flag.dart';

/// 광고 단위 ID (docs/07-MONETIZATION.md · docs/08-OPERATIONS.md)
///
/// **빌드 종류가 ID 를 결정한다. 사람이 기억해서 바꾸지 않는다.**
///
/// 실기기 테스트에서 실제 광고 ID 를 쓰면 무효 트래픽으로 집계되고,
/// 반복되면 계정이 정지된다. 정지되면 이 계정으로 만든 다른 앱의 수익도
/// 함께 끊긴다.
abstract final class AdUnitIds {
  /// Google 이 공개한 테스트 전면광고 ID.
  ///
  /// 실제 광고가 아니므로 무효 트래픽으로 집계되지 않는다.
  static const _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  /// Google 이 공개한 테스트 배너 ID (적응형 배너도 같은 단위를 쓴다).
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2435281174';

  /// 프로덕션 광고 단위 ID.
  ///
  /// **공개 정보라 소스에 둔다** — APK 를 뜯으면 그대로 나오므로 숨기는
  /// 것이 의미가 없다. 앱 ID(매니페스트)와 같은 성격이다.
  ///
  /// 예전에는 `String.fromEnvironment` 로 받았는데, **CI 가 `--dart-define`
  /// 을 넘기지 않아 릴리스 빌드도 테스트 광고로 나가고 있었다.** 그
  /// 워크플로우는 템플릿이 관리해서 고쳐도 다음 갱신에 덮인다.
  static const _prodInterstitialAndroid =
      'ca-app-pub-2025665624324395/6789282892';

  /// iOS 는 AdMob 앱 미등록 (#51 로 서명이 막혀 있다).
  /// 비어 있으면 테스트 ID 로 떨어진다.
  static const _prodInterstitialIos = '';

  /// 배너 광고 단위 `banner_bottom` (이슈 #186, #187 — 2026-10-02 콘솔에서 생성).
  ///
  /// **비어 있으면 릴리스 빌드도 테스트 배너다.** 콘솔에 없는 단위로 실제
  /// 요청을 보내면 노출 없이 요청만 쌓이고, 이름 없는 단위가 섞여 집계가
  /// 어지러워진다. 광고가 안 나가는 쪽이 안전하다.
  static const _prodBannerAndroid = 'ca-app-pub-2025665624324395/5000175615';
  static const _prodBannerIos = '';

  /// 지금 빌드에서 써야 할 전면광고 ID
  ///
  /// **실제 광고는 배포 빌드임이 확인됐을 때만 나간다** (이슈 #109).
  /// 디버그 빌드, 검증 빌드(`DEV_FLAG=true`), 그리고 **빌드 성격을 읽지
  /// 못한 경우**까지 전부 테스트 광고다.
  ///
  /// 실기기 검증에서 실제 광고를 반복 노출하면 무효 트래픽으로 집계되고,
  /// 누적되면 계정이 정지된다 — 정지되면 이 계정의 다른 앱 수익도 함께
  /// 끊긴다. 광고가 안 나가는 것은 그에 비하면 사소한 손실이다.
  static String get interstitial => _pick(
    test: _testInterstitial,
    prodAndroid: _prodInterstitialAndroid,
    prodIos: _prodInterstitialIos,
  );

  /// 지금 빌드에서 써야 할 배너 ID — 전면광고와 같은 규칙이다 (이슈 #186)
  static String get banner => _pick(
    test: _testBanner,
    prodAndroid: _prodBannerAndroid,
    prodIos: _prodBannerIos,
  );

  /// 실제 단위는 배포 빌드가 확인됐고 값이 있을 때만 쓴다. 나머지는 전부 테스트다.
  static String _pick({
    required String test,
    required String prodAndroid,
    required String prodIos,
  }) {
    if (kDebugMode) return test;
    if (!DevFlag.isReleaseBuildConfirmed) return test;

    final prod = Platform.isIOS ? prodIos : prodAndroid;
    return prod.isEmpty ? test : prod;
  }

  static String get _testInterstitial =>
      Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid;

  static String get _testBanner =>
      Platform.isIOS ? _testBannerIos : _testBannerAndroid;

  /// 지금 테스트 ID 를 쓰고 있는가 — 진단 표시용
  static bool get usingTestIds => interstitial == _testInterstitial;
}
