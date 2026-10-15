import 'package:ear_loc_alert/app/geofence_event_retention.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 90일 지난 진입 기록 삭제 (docs/03-DOMAIN.md — 아키텍처 검수 #276)
class _RecordingEventRepository implements GeofenceEventRepository {
  DateTime? deletedBefore;

  @override
  Future<int> deleteOlderThan(DateTime cutoffUtc) async {
    deletedBefore = cutoffUtc;
    return 3;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingEventRepository extends _RecordingEventRepository {
  @override
  Future<int> deleteOlderThan(DateTime cutoffUtc) async =>
      throw StateError('db closed');
}

void main() {
  test('지금으로부터 90일 전보다 오래된 기록을 지운다', () async {
    final events = _RecordingEventRepository();
    final deleted = await deleteGeofenceEventsPastRetention(
      events: events,
      now: DateTime.utc(2026, 10, 15),
    );
    expect(deleted, 3);
    expect(events.deletedBefore, DateTime.utc(2026, 7, 17));
  });

  test('삭제가 실패해도 앱 시작을 막지 않는다 — 0 을 돌려준다', () async {
    final deleted = await deleteGeofenceEventsPastRetention(
      events: _FailingEventRepository(),
      now: DateTime.utc(2026, 10, 15),
    );
    expect(deleted, 0);
  });
}
