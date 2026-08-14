import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/geofence/data/android_geofence_monitor.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_target.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android 지오펜스 등록 어댑터 (이슈 #93)
///
/// native_geofence 의 WorkManager 경유를 버리고 앱이 직접 등록한다.
/// 이 테스트가 지키는 것은 **채널 페이로드 계약**이다 — Kotlin
/// `GeofenceRegistrar.sync` 가 읽는 키와 어긋나면 등록이 조용히 실패한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('kr.suhsaechan.ear_loc_alert/alert_window');
  final calls = <MethodCall>[];

  void mockChannel({List<String> registeredIds = const ['old-place']}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'registeredPlaceIds') return registeredIds;
          return null;
        });
  }

  setUp(() {
    calls.clear();
    mockChannel();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const target = GeofenceTarget(
    placeId: 'place-1',
    latitude: 37.5663,
    longitude: 126.9779,
    radiusMeters: 100,
    direction: AlertDirection.both,
  );

  test('sync 는 실제 반경과 근접 반경을 함께 넘긴다', () async {
    await const AndroidGeofenceMonitor().sync([target]);

    final call = calls.singleWhere((c) => c.method == 'syncGeofences');
    final fences = (call.arguments as Map)['geofences'] as List;
    expect(fences, hasLength(1));

    final fence = fences.first as Map;
    expect(fence['placeId'], 'place-1');
    expect(fence['latitude'], 37.5663);
    expect(fence['longitude'], 126.9779);
    expect(fence['radiusMeters'], 100.0);
    // 100 × 3 = 300 < 500 → 하한이 적용된다
    expect(fence['proximityRadiusMeters'], 500.0);
  });

  test('여러 장소를 한 번에 넘긴다', () async {
    await const AndroidGeofenceMonitor().sync([
      target,
      target.copyWith(placeId: 'place-2', radiusMeters: 500),
    ]);

    final call = calls.singleWhere((c) => c.method == 'syncGeofences');
    final fences = (call.arguments as Map)['geofences'] as List;
    expect(fences, hasLength(2));
    expect((fences[1] as Map)['proximityRadiusMeters'], 1500.0);
  });

  test('빈 목록도 그대로 전달한다 — 전체 해제를 뜻한다', () async {
    await const AndroidGeofenceMonitor().sync([]);

    final call = calls.singleWhere((c) => c.method == 'syncGeofences');
    expect((call.arguments as Map)['geofences'], isEmpty);
  });

  test('stopAll 은 빈 목록 동기화다', () async {
    await const AndroidGeofenceMonitor().stopAll();

    final call = calls.singleWhere((c) => c.method == 'syncGeofences');
    expect((call.arguments as Map)['geofences'], isEmpty);
  });

  test('registeredPlaceIds 는 네이티브 응답을 그대로 돌려준다', () async {
    final ids = await const AndroidGeofenceMonitor().registeredPlaceIds();
    expect(ids, ['old-place']);
  });

  test('등록된 것이 없으면 빈 목록이다', () async {
    mockChannel(registeredIds: const []);
    expect(await const AndroidGeofenceMonitor().registeredPlaceIds(), isEmpty);
  });

  test('채널이 없어도 예외를 올리지 않는다', () async {
    // 서비스를 못 띄우는 것은 알림이 약해지는 일이지 앱이 멈출 일이 아니다.
    // 등록 실패는 다음 장소 변경 때 재시도된다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    await const AndroidGeofenceMonitor().sync([target]);
    expect(await const AndroidGeofenceMonitor().registeredPlaceIds(), isEmpty);
  });

  test('네이티브가 예외를 던져도 삼킨다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'PERMISSION_DENIED');
        });

    await const AndroidGeofenceMonitor().sync([target]);
    expect(await const AndroidGeofenceMonitor().registeredPlaceIds(), isEmpty);
  });
}
