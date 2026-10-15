import '../core/diagnostics/diagnostics.dart';
import '../core/domain/retention_policy.dart';
import '../features/geofence/domain/geofence_event_repository.dart';

/// 보관 기간(90일)이 지난 진입·이탈 기록을 지운다 (docs/03-DOMAIN.md)
///
/// 앱 시작 때 한 번 부른다. 한동안 아무도 부르지 않아 기록이 끝없이
/// 쌓였다 (아키텍처 검수 #276). **실패해도 던지지 않는다** — 오래된 기록이
/// 남는 것보다 앱이 뜨지 않는 쪽이 훨씬 나쁘다. 지운 건수는 0 으로 돌려준다.
Future<int> deleteGeofenceEventsPastRetention({
  required GeofenceEventRepository events,
  required DateTime now,
}) async {
  final cutoff = RetentionPolicy.cutoffFrom(now);
  try {
    final deleted = await events.deleteOlderThan(cutoff);
    Diagnostics.log(
      'geofence',
      'old events deleted count=$deleted before=${cutoff.toIso8601String()}',
    );
    return deleted;
  } on Object catch (error) {
    Diagnostics.log('geofence', 'old events delete failed error=$error');
    return 0;
  }
}
