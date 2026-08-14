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

  Map<String, Object?> toMap() => {
    'shouldAlert': shouldAlert,
    'placeId': placeId,
    'placeName': placeName,
    'direction': direction,
    'soundEnabled': soundEnabled,
  };
}
