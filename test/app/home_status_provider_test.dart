import 'package:ear_loc_alert/app/geofence_providers.dart';
import 'package:ear_loc_alert/app/home_status_provider.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:ear_loc_alert/features/alert/presentation/alert_controller_provider.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_monitor.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMonitor implements GeofenceMonitor {
  FakeMonitor({this.registered = const [], this.failOnQuery = false});

  final List<String> registered;
  final bool failOnQuery;

  @override
  Future<List<String>> registeredPlaceIds() async {
    if (failOnQuery) throw Exception('플랫폼 채널 실패');
    return registered;
  }

  @override
  Future<void> sync(List<GeofenceTarget> targets) async {}

  @override
  Future<void> stopAll() async {}
}

class FakeSound implements AlertSoundService {
  FakeSound({this.connected = false, this.failOnCheck = false});

  final bool connected;
  final bool failOnCheck;

  @override
  Future<bool> isHeadphoneConnected() async {
    if (failOnCheck) throw Exception('오디오 세션 실패');
    return connected;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}
}

/// 메인 화면 상태 바의 값 (docs/06-UX.md F4.5)
///
/// **실패해도 예외가 새어나가면 안 된다** — 상태 표시가 안 된다고
/// 홈 화면이 깨지면 안 되고, 모르면 보수적으로 "꺼짐"이다.
void main() {
  ProviderContainer makeContainer({
    required GeofenceMonitor monitor,
    required AlertSoundService sound,
  }) {
    final container = ProviderContainer(
      overrides: [
        geofenceMonitorProvider.overrideWithValue(monitor),
        alertSoundServiceProvider.overrideWithValue(sound),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('홈 상태', () {
    test('지오펜스 등록 있음 + 이어폰 연결 → 둘 다 켜짐', () async {
      final container = makeContainer(
        monitor: FakeMonitor(registered: ['p1']),
        sound: FakeSound(connected: true),
      );

      final status = await container.read(homeStatusProvider.future);

      expect(status.isMonitoring, isTrue);
      expect(status.isHeadphoneConnected, isTrue);
    });

    test('등록 0건 → 감시 꺼짐으로 표시된다', () async {
      final container = makeContainer(
        monitor: FakeMonitor(),
        sound: FakeSound(connected: true),
      );

      final status = await container.read(homeStatusProvider.future);

      expect(status.isMonitoring, isFalse);
    });

    test('지오펜스 조회가 실패해도 예외가 새지 않고 꺼짐으로 본다', () async {
      final container = makeContainer(
        monitor: FakeMonitor(failOnQuery: true),
        sound: FakeSound(connected: true),
      );

      final status = await container.read(homeStatusProvider.future);

      expect(status.isMonitoring, isFalse);
      // 한쪽 실패가 다른 쪽 값을 오염시키지 않는다
      expect(status.isHeadphoneConnected, isTrue);
    });

    test('이어폰 확인이 실패해도 예외가 새지 않고 미연결로 본다', () async {
      final container = makeContainer(
        monitor: FakeMonitor(registered: ['p1']),
        sound: FakeSound(failOnCheck: true),
      );

      final status = await container.read(homeStatusProvider.future);

      expect(status.isHeadphoneConnected, isFalse);
      expect(status.isMonitoring, isTrue);
    });

    test('확인 전 기본값은 보수적으로 전부 꺼짐이다', () {
      expect(HomeStatus.unknown.isMonitoring, isFalse);
      expect(HomeStatus.unknown.isHeadphoneConnected, isFalse);
    });
  });
}
