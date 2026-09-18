import 'package:ear_loc_alert/app/background/pending_alert.dart';
import 'package:ear_loc_alert/app/background/pending_alert_store.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 백그라운드 알림의 isolate 간 전달 (이슈 #63 · #125)
///
/// **이 저장소에 테스트가 없어서 이슈 #125 가 났다.** 알림음 필드를
/// 추가하면서 `_clear` 뒤에서 읽는 코드를 넣었고, 그 결과 장소마다
/// 고른 소리가 전부 기본음으로 떨어졌다. 예외도 로그도 없이 조용히.
///
/// 그래서 여기서는 필드 하나가 아니라 **왕복 전체**를 본다 — 다음에
/// 필드를 더할 때 같은 실수가 반복되면 바로 걸리도록.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PendingAlertStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = PendingAlertStore();
  });

  PendingAlert makeAlert({
    AlertSound sound = AlertSound.fallback,
    bool soundEnabled = true,
    AlertDirection direction = AlertDirection.enter,
  }) {
    return PendingAlert(
      placeId: 'p1',
      placeName: '소만사 출근',
      direction: direction,
      soundEnabled: soundEnabled,
      occurredAt: DateTime.utc(2026, 9, 1, 23, 3, 20),
      sound: sound,
    );
  }

  group('왕복', () {
    test('저장한 값이 그대로 돌아온다', () async {
      final saved = makeAlert(sound: const PresetSound(SoundPreset.siren));
      await store.save(saved);

      final (:alert, :hadStored) = await store.take();

      expect(hadStored, isTrue);
      expect(alert, isNotNull);
      expect(alert!.placeId, 'p1');
      expect(alert.placeName, '소만사 출근');
      expect(alert.direction, AlertDirection.enter);
      expect(alert.soundEnabled, isTrue);
      expect(alert.occurredAt, DateTime.utc(2026, 9, 1, 23, 3, 20));
      expect(
        alert.sound,
        const PresetSound(SoundPreset.siren),
        reason: '이슈 #125 — 지운 뒤에 읽으면 여기서 기본음이 나온다',
      );
    });

    test('모든 프리셋이 왕복한다', () async {
      for (final preset in SoundPreset.values) {
        SharedPreferences.setMockInitialValues({});
        await store.save(makeAlert(sound: PresetSound(preset)));

        final (:alert, :hadStored) = await store.take();

        expect(alert!.sound, PresetSound(preset), reason: '${preset.id} 유실');
      }
    });

    test('사용자 음원이 왕복한다', () async {
      await store.save(makeAlert(sound: const CustomSoundRef('u-1')));

      final (:alert, :hadStored) = await store.take();

      expect(alert!.sound, const CustomSoundRef('u-1'));
    });

    test('이탈 방향과 소리 끔도 왕복한다', () async {
      await store.save(
        makeAlert(direction: AlertDirection.exit, soundEnabled: false),
      );

      final (:alert, :hadStored) = await store.take();

      expect(alert!.direction, AlertDirection.exit);
      expect(alert.soundEnabled, isFalse);
    });
  });

  group('꺼내면 사라진다', () {
    test('두 번째 take 는 비어 있다', () async {
      await store.save(makeAlert(sound: const PresetSound(SoundPreset.bell)));
      await store.take();

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNull);
      expect(hadStored, isFalse, reason: '같은 알림이 두 번 승격되면 진동이 두 번 시작된다');
    });

    test('알림음 키도 함께 지워진다', () async {
      await store.save(makeAlert(sound: const PresetSound(SoundPreset.siren)));
      await store.take();

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      expect(
        prefs.getString('pending_alert.sound'),
        isNull,
        reason: '남아 있으면 다음 알림이 엉뚱한 소리로 울린다',
      );
    });
  });

  group('없거나 깨진 값', () {
    test('저장된 것이 없으면 hadStored 가 false 다', () async {
      final (:alert, :hadStored) = await store.take();

      expect(alert, isNull);
      expect(hadStored, isFalse);
    });

    test('알림음 키가 없으면 기본음으로 올라온다', () async {
      // 이 필드가 없던 버전에서 저장된 값을 읽는 경우다
      SharedPreferences.setMockInitialValues({
        'pending_alert.place_id': 'p1',
        'pending_alert.place_name': '회사',
        'pending_alert.direction': 'enter',
        'pending_alert.sound_enabled': true,
        'pending_alert.occurred_at': '2026-09-01T23:03:20.000Z',
      });

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNotNull);
      expect(
        alert!.sound,
        AlertSound.fallback,
        reason: '알림음 하나 때문에 알림 전체를 버리면 안 된다',
      );
    });

    test('알림음 값이 깨져도 알림은 살아 있다', () async {
      SharedPreferences.setMockInitialValues({
        'pending_alert.place_id': 'p1',
        'pending_alert.place_name': '회사',
        'pending_alert.direction': 'enter',
        'pending_alert.sound_enabled': true,
        'pending_alert.occurred_at': '2026-09-01T23:03:20.000Z',
        'pending_alert.sound': 'garbage!!',
      });

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNotNull);
      expect(alert!.sound, AlertSound.fallback);
    });

    test('방향이 깨지면 알림을 버리되 꺼낸 것으로 친다', () async {
      SharedPreferences.setMockInitialValues({
        'pending_alert.place_id': 'p1',
        'pending_alert.place_name': '회사',
        'pending_alert.direction': 'sideways',
        'pending_alert.sound_enabled': true,
        'pending_alert.occurred_at': '2026-09-01T23:03:20.000Z',
      });

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNull);
      expect(
        hadStored,
        isTrue,
        reason: '네이티브가 그 알림으로 진동 중이다 — 끌 수 있어야 한다 (이슈 #83)',
      );
    });
  });

  /// 좌표 왕복 (이슈 #142)
  ///
  /// **#125 가 났던 자리에 필드를 또 더했다.** `_clear` 앞에서 읽는지를
  /// 여기서 지킨다 — 뒤로 옮기는 순간 이 테스트가 깨진다.
  group('지도 좌표', () {
    test('좌표와 반경이 왕복해도 살아 돌아온다', () async {
      await store.save(
        makeAlert().copyWith(
          latitude: 37.5665,
          longitude: 126.9780,
          radiusMeters: 200,
        ),
      );

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNotNull);
      expect(alert!.latitude, closeTo(37.5665, 1e-9));
      expect(alert.longitude, closeTo(126.9780, 1e-9));
      expect(alert.radiusMeters, 200);
    });

    test('좌표 없이 저장한 알림은 좌표 없이 돌아온다', () async {
      await store.save(makeAlert());

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNotNull);
      expect(alert!.latitude, isNull);
      expect(alert.longitude, isNull);
      expect(alert.radiusMeters, isNull);
    });

    test('좌표 키가 아예 없는 구버전 저장분도 읽힌다', () async {
      SharedPreferences.setMockInitialValues({
        'pending_alert.place_id': 'p1',
        'pending_alert.place_name': '회사',
        'pending_alert.direction': 'enter',
        'pending_alert.sound_enabled': true,
        'pending_alert.occurred_at': '2026-09-01T23:03:20.000Z',
      });

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNotNull, reason: '좌표가 없다고 알림을 버리면 안 된다');
      expect(alert!.latitude, isNull);
    });

    test('반경만 있고 좌표가 없으면 셋 다 버린다', () async {
      SharedPreferences.setMockInitialValues({
        'pending_alert.place_id': 'p1',
        'pending_alert.place_name': '회사',
        'pending_alert.direction': 'enter',
        'pending_alert.sound_enabled': true,
        'pending_alert.occurred_at': '2026-09-01T23:03:20.000Z',
        'pending_alert.radius_meters': 200,
      });

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNotNull);
      expect(
        alert!.radiusMeters,
        isNull,
        reason: '반쪽짜리 좌표로 지도를 그리면 엉뚱한 곳이 뜬다',
      );
    });

    test('좌표도 함께 지워진다 — 다음 take 에 남지 않는다', () async {
      await store.save(
        makeAlert().copyWith(
          latitude: 37.5665,
          longitude: 126.9780,
          radiusMeters: 200,
        ),
      );
      await store.take();

      final (:alert, :hadStored) = await store.take();

      expect(alert, isNull);
      expect(hadStored, isFalse);
    });
  });
}
