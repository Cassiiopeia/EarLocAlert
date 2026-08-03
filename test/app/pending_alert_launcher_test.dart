import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/app/background/pending_alert_store.dart';
import 'package:ear_loc_alert/app/pending_alert_launcher.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 백그라운드 알림 → 포그라운드 세션 승격 (이슈 #63)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 4, 12);

  PendingAlert alert({required DateTime occurredAt}) => PendingAlert(
    placeId: 'place-1',
    placeName: '독서실',
    direction: AlertDirection.enter,
    soundEnabled: true,
    occurredAt: occurredAt,
  );

  late PendingAlertStore store;
  late PendingAlertLauncher launcher;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = PendingAlertStore();
    launcher = PendingAlertLauncher(store: store, clock: () => now);
  });

  test('TTL 이내의 알림은 발화 요청으로 바뀐다', () async {
    await store.save(
      alert(occurredAt: now.subtract(const Duration(minutes: 5))),
    );

    final request = await launcher.takeRequest();

    expect(request, isNotNull);
    expect(request!.placeId, 'place-1');
    expect(request.placeName, '독서실');
    expect(request.direction, AlertDirection.enter);
    expect(request.soundEnabled, isTrue);
  });

  test('TTL(10분)이 지난 알림은 버린다 — 아침에 열어도 진동이 터지지 않는다', () async {
    await store.save(alert(occurredAt: now.subtract(const Duration(hours: 3))));

    expect(await launcher.takeRequest(), isNull);
  });

  test('없으면 null', () async {
    expect(await launcher.takeRequest(), isNull);
  });

  test('한 번 꺼내면 사라진다 — resume 마다 재발화되면 안 된다', () async {
    await store.save(alert(occurredAt: now));

    expect(await launcher.takeRequest(), isNotNull);
    expect(await launcher.takeRequest(), isNull);
  });

  test('저장 값이 깨져 있으면 null (부분 저장 실패 방어)', () async {
    SharedPreferences.setMockInitialValues({
      'pending_alert.place_id': 'place-1',
      // 나머지 키 없음
    });

    expect(await launcher.takeRequest(), isNull);
  });
}
