import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/features/geofence/domain/alert_suppression.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_evaluation.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림이 나가지 않은 이유 (이슈 #127)
///
/// **"왜 안 울렸는가"가 이 앱에서 가장 자주 묻는 질문이다.** 그동안
/// 로그는 여섯 가지 상황을 `알림 없음` 한 줄로 뭉갰다. 사용자가 겪은
/// 그 순간은 재현되지 않으므로, 남은 기록이 갈라주지 못하면 끝이다.
void main() {
  GeofenceTarget makeTarget({
    bool enabled = true,
    AlertDirection direction = AlertDirection.enter,
    List<AlertSchedule> schedules = const [],
  }) {
    return GeofenceTarget(
      placeId: 'p1',
      latitude: 37.5,
      longitude: 127.0,
      radiusMeters: 100,
      direction: direction,
      enabled: enabled,
      schedules: schedules,
    );
  }

  group('suppressionOf', () {
    test('조건이 맞으면 막지 않는다', () {
      expect(
        suppressionOf(
          target: makeTarget(),
          transition: GeofenceTransition.entered,
          scheduleActive: true,
        ),
        isNull,
      );
    });

    test('꺼둔 장소', () {
      expect(
        suppressionOf(
          target: makeTarget(enabled: false),
          transition: GeofenceTransition.entered,
          scheduleActive: true,
        ),
        AlertSuppression.placeDisabled,
      );
    });

    test('전이가 없으면 전이없음', () {
      expect(
        suppressionOf(
          target: makeTarget(),
          transition: GeofenceTransition.none,
          scheduleActive: true,
        ),
        AlertSuppression.noTransition,
      );
    });

    test('정확도 부족은 전이없음과 구분된다', () {
      expect(
        suppressionOf(
          target: makeTarget(),
          transition: GeofenceTransition.deferred,
          scheduleActive: true,
        ),
        AlertSuppression.deferred,
        reason:
            'GPS 가 나빠서인지 움직이지 않아서인지 가르지 못하면 '
            '실내·지하에서 왜 안 울렸는지 영영 알 수 없다',
      );
    });

    test('도착만 켠 장소에서 이탈하면 방향불일치', () {
      expect(
        suppressionOf(
          target: makeTarget(direction: AlertDirection.enter),
          transition: GeofenceTransition.exited,
          scheduleActive: true,
        ),
        AlertSuppression.directionMismatch,
      );
    });

    test('양방향 장소는 이탈에도 막지 않는다', () {
      expect(
        suppressionOf(
          target: makeTarget(direction: AlertDirection.both),
          transition: GeofenceTransition.exited,
          scheduleActive: true,
        ),
        isNull,
      );
    });

    test('시간대 밖', () {
      expect(
        suppressionOf(
          target: makeTarget(),
          transition: GeofenceTransition.entered,
          scheduleActive: false,
        ),
        AlertSuppression.outsideSchedule,
      );
    });

    test('전이가 없으면 시간대보다 먼저 걸린다', () {
      expect(
        suppressionOf(
          target: makeTarget(),
          transition: GeofenceTransition.none,
          scheduleActive: false,
        ),
        AlertSuppression.noTransition,
        reason: '"시간대밖"으로 기록되면 창을 고치면 울릴 것처럼 오해한다',
      );
    });

    test('꺼둔 장소가 가장 먼저 걸린다', () {
      expect(
        suppressionOf(
          target: makeTarget(enabled: false),
          transition: GeofenceTransition.none,
          scheduleActive: false,
        ),
        AlertSuppression.placeDisabled,
        reason: '가장 단순한 답을 먼저 보여준다',
      );
    });

    test('모든 사유가 서로 다른 라벨을 가진다', () {
      final labels = AlertSuppression.values.map((s) => s.label).toSet();
      expect(labels.length, AlertSuppression.values.length);
    });
  });

  group('formatDecision', () {
    test('알림이 나가면 방향을 남긴다', () {
      final line = formatDecision(
        placeId: '019fc9f2-edd1-71ef-a677-c3a388c8ea25',
        placeName: '소만사 출근',
        transition: GeofenceTransition.entered,
        suppression: null,
        direction: AlertDirection.enter,
      );

      expect(line, contains('019fc9f2'));
      expect(line, isNot(contains('c3a388c8ea25')), reason: '앞 8자만 쓴다');
      expect(line, contains('소만사 출근'));
      expect(line, contains('→ 알림'));
      expect(line, isNot(contains('알림없음')));
    });

    test('사유를 남긴다', () {
      final line = formatDecision(
        placeId: 'p1',
        placeName: '회사',
        transition: GeofenceTransition.none,
        suppression: AlertSuppression.noTransition,
      );

      expect(line, contains('알림없음'));
      expect(line, contains('전이없음'));
    });

    test('정확도 부족은 실제 값을 함께 남긴다', () {
      final line = formatDecision(
        placeId: 'p1',
        placeName: '회사',
        transition: GeofenceTransition.deferred,
        suppression: AlertSuppression.deferred,
        accuracyMeters: 343.101,
      );

      expect(line, contains('343m'), reason: '숫자가 없으면 얼마나 나빴는지 알 수 없다');
    });

    test('방향불일치는 장소 설정을 함께 남긴다', () {
      final line = formatDecision(
        placeId: 'p1',
        placeName: '회사',
        transition: GeofenceTransition.exited,
        suppression: AlertSuppression.directionMismatch,
        direction: AlertDirection.enter,
      );

      expect(line, contains('전이=exited'));
      expect(line, contains('설정=enter'));
    });
  });

  group('formatTransition', () {
    test('상태 변화와 좌표를 남긴다', () {
      final line = formatTransition(
        placeId: '019fc9f2-edd1',
        placeName: '소만사 출근',
        from: GeofenceState.outside,
        to: GeofenceState.inside,
        latitude: 37.4117,
        longitude: 127.0954,
        accuracyMeters: 49.586,
      );

      expect(line, contains('019fc9f2'));
      expect(line, contains('outside → inside'));
      expect(line, contains('37.4117'));
      expect(line, contains('50m'), reason: '소수점은 GPS 정확도에 의미가 없다');
    });

    test('좌표가 없어도 깨지지 않는다', () {
      final line = formatTransition(
        placeId: 'p1',
        placeName: '회사',
        from: GeofenceState.unknown,
        to: GeofenceState.inside,
      );

      expect(line, contains('unknown → inside'));
      expect(line, isNot(contains('lat=')));
    });
  });
}
