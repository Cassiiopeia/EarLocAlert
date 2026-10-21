import 'package:flutter/services.dart';
import '../platform/channel_names.dart';

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
  static const _channel = MethodChannel(ChannelNames.appConfig);

  /// 못 읽었을 때의 표기. **빈 문자열이 아니라 물음표다** —
  /// 로그에서 "버전 칸이 비었다"와 "버전을 못 읽었다"가 달라야 한다.
  static const unknown = '?';

  static String _label = unknown;
  static String _deviceLabel = unknown;

  /// 앱 시작 시 한 번 읽는다. 실패해도 조용히 [unknown] 으로 남는다 —
  /// 버전을 못 읽은 것이 앱을 멈출 이유는 없다.
  static Future<void> init() async {
    try {
      _label = await _channel.invokeMethod<String>('versionLabel') ?? unknown;
    } on Object {
      // 채널 미등록·응답 실패 > 물음표로 표기
      _label = unknown;
    }
    // 기기·앱 기본 정보 (이슈 #260) — 개인을 특정하는 값은 담지 않는다
    try {
      _deviceLabel =
          await _channel.invokeMethod<String>('deviceInfo') ?? unknown;
    } on Object {
      _deviceLabel = unknown;
    }
  }

  /// `maker=samsung model=SM-S911N android=15(sdk35) ...` 형태의 한 줄.
  /// 못 읽었으면 [unknown].
  static String get deviceLabel => _deviceLabel;

  /// `1.13.1(95)` 형태
  static String get label => _label;

  /// 진단 보고서용 네이티브 상태 전체 (이슈 #290, Kotlin·Swift `DebugSnapshot`).
  /// 실패해도 예외 없이 사유 한 줄
  static Future<String> readNativeSnapshot() async {
    try {
      return await _channel.invokeMethod<String>('debugSnapshot') ??
          'unavailable reason=empty_response';
    } on Object catch (error) {
      return 'unavailable error=$error';
    }
  }
}
