/// 네이티브에 돌려줄 판정 결과 (이슈 #93)
///
/// freezed 를 쓰지 않는 이유는 이것이 **채널 경계의 전송 형태**이기
/// 때문이다. 도메인 값이 아니라 Map 으로 나가는 것이 목적이고, 키 이름이
/// Kotlin `AlertDecision.fromMap` 과의 계약이다 — 한 곳에서 눈으로
/// 확인되어야 한다.
class AlertDecision {
  const AlertDecision({
    required this.shouldAlert,
    this.placeId,
    this.placeName,
    this.direction,
    this.soundEnabled = true,
    this.vibrationAmplitude = 0,
    this.vibrationPulseMs = 0,
  });

  /// 알림 없음 — 가장 흔한 결과다.
  ///
  /// 판정 실패도 이 값으로 떨어진다. 백그라운드에서 예외를 올리면
  /// 감시만 조용히 죽는다.
  static const none = AlertDecision(shouldAlert: false);

  final bool shouldAlert;
  final String? placeId;
  final String? placeName;

  /// `enter` 또는 `exit` — `AlertDirection.name` 과 같은 문자열이다
  final String? direction;
  final bool soundEnabled;

  /// 사용자가 설정한 진동 세기 (이슈 #103).
  ///
  /// **왜 네이티브가 설정을 직접 읽지 않나** — 설정을 읽는 자리가 둘이 되면
  /// 반드시 어긋난다. 판정은 Dart 에 있고, 그 결과에 실어 보내면 값의
  /// 출처가 하나로 유지된다.
  ///
  /// 0 은 "설정 없음"이다 — 네이티브가 기존 기본 진동으로 떨어진다.
  final int vibrationAmplitude;

  /// 한 번의 진동 길이(ms). 0 이면 네이티브 기본 패턴을 쓴다.
  final int vibrationPulseMs;

  Map<String, Object?> toMap() => {
    'shouldAlert': shouldAlert,
    'placeId': placeId,
    'placeName': placeName,
    'direction': direction,
    'soundEnabled': soundEnabled,
    'vibrationAmplitude': vibrationAmplitude,
    'vibrationPulseMs': vibrationPulseMs,
  };
}
