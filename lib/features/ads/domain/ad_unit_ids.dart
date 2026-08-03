import 'dart:io';

import 'package:flutter/foundation.dart';

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
  /// AdMob 앱 등록 후 발급받아 채운다. 비어 있으면 릴리스 빌드에서도
  /// 테스트 ID 를 쓴다 — **잘못된 ID 로 요청해 계정에 흠집을 내는 것보다
  /// 광고가 안 나가는 편이 낫다.**
  static const _prodInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
  );
  static const _prodInterstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
  );

  /// 지금 빌드에서 써야 할 전면광고 ID
  static String get interstitial {
    if (kDebugMode) return _testInterstitial;

    final prod = Platform.isIOS
        ? _prodInterstitialIos
        : _prodInterstitialAndroid;
    return prod.isEmpty ? _testInterstitial : prod;
  }

  static String get _testInterstitial =>
      Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid;

  /// 지금 테스트 ID 를 쓰고 있는가 — 진단 표시용
  static bool get usingTestIds {
    if (kDebugMode) return true;
    final prod = Platform.isIOS
        ? _prodInterstitialIos
        : _prodInterstitialAndroid;
    return prod.isEmpty;
  }
}
