import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/app/background/pending_alert_store.dart';
import 'package:ear_loc_alert/app/pending_alert_launcher.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 백그라운드 알림 → 포그라운드 세션 승격 (이슈 #63 · #83)
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

    final (:request, :hadPending) = await launcher.takeRequest();

    expect(hadPending, isTrue);
    expect(request, isNotNull);
    expect(request!.placeId, 'place-1');
    expect(request.placeName, '독서실');
    expect(request.direction, AlertDirection.enter);
    expect(request.soundEnabled, isTrue);
  });

  test('TTL(10분)이 지난 알림은 승격하지 않는다 — 아침에 열어도 진동이 터지지 않는다', () async {
    await store.save(alert(occurredAt: now.subtract(const Duration(hours: 3))));

    final (:request, :hadPending) = await launcher.takeRequest();

    expect(request, isNull);
    // **회귀 가드 (이슈 #83).** 승격은 안 하지만 꺼낼 것은 있었다.
    // 이 값이 false 로 돌아가면 호출자가 네이티브 진동을 끊지 않아,
    // 울리는데 끌 화면이 없는 상태가 된다.
    expect(hadPending, isTrue, reason: '만료된 알림도 네이티브는 울리고 있다 — 정리 대상임을 알려야 한다');
  });

  test('시계가 뒤로 간 경우(미래 시각)도 승격하지 않되 정리 대상이다', () async {
    await store.save(alert(occurredAt: now.add(const Duration(hours: 1))));

    final (:request, :hadPending) = await launcher.takeRequest();

    expect(request, isNull);
    expect(hadPending, isTrue);
  });

  test('없으면 꺼낼 것도 없다 — 네이티브를 건드릴 이유가 없다', () async {
    final (:request, :hadPending) = await launcher.takeRequest();

    expect(request, isNull);
    // 여기서 true 가 되면 앱이 떠 있는 내내 폴링마다 네이티브 정지를
    // 호출하게 된다. 방금 시작된 알림을 지워버릴 수 있다.
    expect(hadPending, isFalse);
  });

  test('한 번 꺼내면 사라진다 — resume 마다 재발화되면 안 된다', () async {
    await store.save(alert(occurredAt: now));

    expect((await launcher.takeRequest()).request, isNotNull);

    final second = await launcher.takeRequest();
    expect(second.request, isNull);
    expect(second.hadPending, isFalse);
  });

  test('저장 값이 깨져 있으면 승격하지 않되 정리 대상이다 (부분 저장 실패 방어)', () async {
    SharedPreferences.setMockInitialValues({
      'pending_alert.place_id': 'place-1',
      // 나머지 키 없음
    });

    final (:request, :hadPending) = await launcher.takeRequest();

    expect(request, isNull);
    // **회귀 가드 (이슈 #83).** 읽지 못했다는 이유로 진동을 남겨두면
    // 끌 방법이 사라진다.
    expect(hadPending, isTrue);
  });

  test('깨진 값은 꺼낸 뒤 지워진다 — 다음 번엔 정리 대상이 아니다', () async {
    SharedPreferences.setMockInitialValues({
      'pending_alert.place_id': 'place-1',
    });

    await launcher.takeRequest();
    final second = await launcher.takeRequest();

    expect(second.hadPending, isFalse);
  });
}
