import 'dart:io';

import 'package:flutter/services.dart';

/// 개발·검증 빌드 여부 (이슈 #109)
///
/// `.env` 의 `DEV_FLAG` 를 gradle 이 `BuildConfig` 에 넣고, 여기서 채널로
/// 읽는다. **하나의 값이 두 가지를 가른다:**
///
/// | 값 | 인앱 업데이트 | 광고 |
/// |---|---|---|
/// | `true` (검증 빌드) | 있음 | **테스트 광고** |
/// | `false` (배포 빌드) | 없음 | 실제 광고 |
/// | 못 읽음 | **없음** | **테스트 광고** |
///
/// **못 읽었을 때 양쪽 다 보수적으로 간다.** 인앱 업데이트가 심사 빌드에
/// 남으면 반려되고, 실제 광고가 검증 빌드에서 나가면 무효 트래픽으로
/// 계정이 정지된다 — 둘 다 되돌리기 어려운 사고라 "모르면 안 한다"가 맞다.
///
/// 그래서 상태가 셋이다. `true`/`false` 이분법으로 두면 못 읽은 경우가
/// 둘 중 한쪽에 붙어 반드시 한 쪽이 위험해진다.
abstract final class DevFlag {
  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/app_config',
  );

  /// null 이면 아직 못 읽었다 — 그 자체가 의미 있는 상태다
  static bool? _value;

  /// 앱 시작 시 한 번 읽는다. 실패하면 못 읽은 상태로 남는다.
  ///
  /// **읽기 전에 광고가 뜰 일은 없다** — 광고는 알림을 해제한 뒤에만
  /// 나오고, 그 시점은 부트스트랩보다 한참 뒤다.
  static Future<void> init() async {
    if (!Platform.isAndroid) {
      // iOS 는 이 플래그를 쓰지 않는다. 인앱 업데이트가 없고(사이드로드
      // 경로 자체가 없다), 광고는 배포 빌드 기준으로 동작한다
      _value = false;
      return;
    }
    try {
      _value = await _channel.invokeMethod<bool>('isDevBuild');
    } on Object {
      _value = null;
    }
  }

  /// 검증용 빌드인가. **못 읽었으면 false** — 인앱 업데이트가 심사
  /// 빌드에 남는 것을 막는 쪽으로 기운다.
  static bool get isDevBuild => _value == true;

  /// **배포 빌드임이 확인됐는가.** 실제 광고를 내보내도 되는 유일한 조건이다.
  ///
  /// 못 읽었을 때 false 라는 점이 핵심이다 — 확신이 없으면 테스트 광고로
  /// 간다. 광고가 안 나가는 것은 수익 손실이지만, 검증 중 실제 광고가
  /// 나가는 것은 계정 정지다.
  static bool get isReleaseBuildConfirmed => _value == false;

  /// 테스트에서 갈아끼운다.
  static void overrideValue(bool? value) => _value = value;
}
