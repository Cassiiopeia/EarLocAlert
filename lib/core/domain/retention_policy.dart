/// 이력 보관 정책 (docs/03-DOMAIN.md)
///
/// `GeofenceEvent` 는 무한히 쌓인다. 기기 저장소를 계속 잠식하면 안 되고,
/// 90일 전 진입 기록이 필요한 사용자는 없다.
abstract final class RetentionPolicy {
  static const Duration eventRetention = Duration(days: 90);

  /// [now] 기준으로 이보다 오래된 이력은 삭제 대상이다.
  ///
  /// 순수 함수라 시각을 주입해 테스트할 수 있다 — `DateTime.now()` 를
  /// 내부에서 부르면 경계 조건 검증이 불가능해진다.
  static DateTime cutoffFrom(DateTime now) =>
      now.toUtc().subtract(eventRetention);
}
