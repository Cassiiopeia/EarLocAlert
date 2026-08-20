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

  /// 프로덕션 광고 단위 ID.
  ///
  /// **공개 정보라 소스에 둔다** — APK 를 뜯으면 그대로 나오므로 숨기는
  /// 것이 의미가 없다. 앱 ID(매니페스트)와 같은 성격이다.
  ///
  /// 예전에는 `String.fromEnvironment` 로 받았는데, **CI 가 `--dart-define`
  /// 을 넘기지 않아 릴리스 빌드도 테스트 광고로 나가고 있었다.** 그
  /// 워크플로우는 템플릿이 관리해서 고쳐도 다음 갱신에 덮인다.
  static const _prodInterstitialAndroid =
      'ca-app-pub-4452677329657064/2338682821';

  /// iOS 는 AdMob 앱 미등록 (#51 로 서명이 막혀 있다).
  /// 비어 있으면 테스트 ID 로 떨어진다.
  static const _prodInterstitialIos = '';

  /// 지금 빌드에서 써야 할 전면광고 ID
  ///
  /// **실제 광고는 배포 빌드임이 확인됐을 때만 나간다** (이슈 #109).
  /// 디버그 빌드, 검증 빌드(`DEV_FLAG=true`), 그리고 **빌드 성격을 읽지
  /// 못한 경우**까지 전부 테스트 광고다.
  ///
  /// 실기기 검증에서 실제 광고를 반복 노출하면 무효 트래픽으로 집계되고,
  /// 누적되면 계정이 정지된다 — 정지되면 이 계정의 다른 앱 수익도 함께
  /// 끊긴다. 광고가 안 나가는 것은 그에 비하면 사소한 손실이다.
  static String get interstitial {
    if (kDebugMode) return _testInterstitial;
    if (!DevFlag.isReleaseBuildConfirmed) return _testInterstitial;

    final prod = Platform.isIOS
        ? _prodInterstitialIos
        : _prodInterstitialAndroid;
    return prod.isEmpty ? _testInterstitial : prod;
  }

  static String get _testInterstitial =>
      Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid;

  /// 지금 테스트 ID 를 쓰고 있는가 — 진단 표시용
  static bool get usingTestIds => interstitial == _testInterstitial;
}
