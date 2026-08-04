import 'audio_route.dart';

/// 진동 제어 (docs/02-ARCHITECTURE.md 규칙 3)
///
/// 플랫폼 API 를 인터페이스 뒤에 둔다 — 알림 흐름을 실기기 없이
/// 테스트하기 위해서다.
abstract interface class VibrationService {
  /// [interval] 간격으로 반복 진동을 시작한다 (F3.1)
  Future<void> startRepeating({required Duration interval});

  /// 즉시 중단한다. **어떤 상황에서도 실패하지 않아야 한다.**
  Future<void> stop();
}

/// 알림음 재생 (docs/03-DOMAIN.md 규칙 5)
abstract interface class AlertSoundService {
  /// **본인만 듣는** 오디오 출력이 연결되어 있는가.
  ///
  /// 유선 이어폰·USB-C 이어폰·블루투스 이어폰을 모두 포함한다.
  /// 스피커로 흘러나갈 수 있는 출력(차량 오디오·AirPlay·HDMI)은 제외한다
  /// (docs/10-DECISIONS.md 018).
  ///
  /// **발화 시점에 확인한다** — 사용자가 방금 이어폰을 빼거나 꽂았을 수 있다.
  Future<bool> isHeadphoneConnected();

  /// 알림음을 재생한다.
  ///
  /// 호출 전에 이어폰 연결이 확인된 상태여야 한다.
  /// 실패하면 [AlertSoundException] 을 던지고, 호출자는 재시도하지 않고
  /// 진동으로 떨어진다 — 재시도 중 라우팅이 바뀌어 스피커로 새는 것이 최악이다.
  Future<void> play();

  Future<void> stop();
}

class AlertSoundException implements Exception {
  const AlertSoundException(this.message);

  final String message;

  @override
  String toString() => 'AlertSoundException: $message';
}

/// 알림 표시 (OS 알림 영역)
abstract interface class AlertNotifier {
  /// 알림을 띄운다. 사용자가 탭하면 앱이 열린다
  Future<void> show({required String placeName, required String body});

  Future<void> dismiss();
}

/// 발화 결과 — 실제로 어떤 경로로 알렸는지
class AlertOutcome {
  const AlertOutcome({required this.audioRoute, required this.soundFailed});

  final AudioRoute audioRoute;

  /// 소리 재생을 시도했으나 실패해 진동으로 떨어졌는가.
  ///
  /// 화면 표시 문구가 달라지고, 반복되면 조사 단서가 된다.
  final bool soundFailed;
}
