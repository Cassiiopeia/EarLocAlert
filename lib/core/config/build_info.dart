import 'package:flutter/services.dart';

/// 실행 중인 빌드가 무엇인지 (이슈 #127)
///
/// **로그에 버전이 없으면 어느 빌드에서 난 문제인지 알 수 없다.**
/// 이슈 #125 를 조사할 때 실제로 그랬다 — v1.12 인지 v1.13 인지
/// 로그로는 알 수 없어 다른 단서로 추론해야 했다.
///
/// `package_info_plus` 를 더하지 않고 [DevFlag] 가 이미 쓰는 채널에
/// 얹는다. 의존성 하나가 앱 크기와 유지보수를 늘리는데, gradle 이
/// `BuildConfig` 에 넣어둔 값을 읽으면 되는 일이다.
abstract final class BuildInfo {
  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/app_config',
  );

  /// 못 읽었을 때의 표기. **빈 문자열이 아니라 물음표다** —
  /// 로그에서 "버전 칸이 비었다"와 "버전을 못 읽었다"가 달라야 한다.
  static const unknown = '?';

  static String _label = unknown;

  /// 앱 시작 시 한 번 읽는다. 실패해도 조용히 [unknown] 으로 남는다 —
  /// 버전을 못 읽은 것이 앱을 멈출 이유는 없다.
  static Future<void> init() async {
    try {
      _label = await _channel.invokeMethod<String>('versionLabel') ?? unknown;
    } on Object {
      // iOS 는 이 채널이 없다. 나중에 필요해지면 그때 붙인다
      _label = unknown;
    }
  }

  /// `1.13.1(95)` 형태
  static String get label => _label;

  /// 테스트에서 갈아끼운다
  static void overrideLabel(String value) => _label = value;
}
