import 'dart:convert';

import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/domain/alert_schedule.dart';
import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_backup.dart';
import 'package:flutter_test/flutter_test.dart';

AlertPlace place({
  String id = 'a',
  String name = '회사',
  double latitude = 37.5,
  double longitude = 127.0,
  int radius = 200,
  AlertDirection direction = AlertDirection.enter,
  AlertSound sound = const PresetSound(SoundPreset.bell),
  List<AlertSchedule> schedules = const [],
}) => AlertPlace(
  id: id,
  name: name,
  latitude: latitude,
  longitude: longitude,
  radiusMeters: radius,
  direction: direction,
  sound: sound,
  schedules: schedules,
  createdAt: DateTime.utc(2026, 1, 1),
);

final now = DateTime.utc(2026, 10, 12, 3);

String file(List<Object?> places, {int version = 1, String? format}) =>
    jsonEncode({
      'format': format ?? PlaceBackup.formatName,
      'schemaVersion': version,
      'places': places,
    });

Map<String, Object?> raw({
  String name = '집',
  Object? lat = 37.5,
  Object? lon = 127.0,
  Object? radius = 100,
}) => {'name': name, 'latitude': lat, 'longitude': lon, 'radiusMeters': radius};

void main() {
  group('내보내기 → 불러오기', () {
    test('모든 필드가 왕복해도 같다 (id·createdAt 제외)', () {
      final original = place(
        direction: AlertDirection.both,
        schedules: [
          const AlertSchedule(
            daysOfWeek: {1, 2, 3},
            startMinuteOfDay: 480,
            endMinuteOfDay: 600,
          ),
        ],
      );

      final exported = PlaceBackup.encode([original], now: now);
      final decoded = PlaceBackup.decode(exported.json, now: now);

      expect(decoded.error, isNull);
      expect(decoded.places, hasLength(1));
      final restored = decoded.places.single;
      expect(restored.name, '회사');
      expect(restored.latitude, 37.5);
      expect(restored.radiusMeters, 200);
      expect(restored.direction, AlertDirection.both);
      expect(restored.sound, const PresetSound(SoundPreset.bell));
      expect(restored.schedules.single.daysOfWeek, {1, 2, 3});
      expect(restored.schedules.single.startMinuteOfDay, 480);
      // id 는 새로 만든다 — 다른 기기·두 번째 불러오기와 겹치지 않는다
      expect(restored.id, isNot(original.id));
    });

    test('사용자 음원은 기본음으로 바꿔 적고 그 수를 알린다', () {
      final exported = PlaceBackup.encode([
        place(sound: const CustomSoundRef('uuid-1')),
        place(id: 'b', name: '집'),
      ], now: now);

      expect(exported.customSoundCount, 1);
      final decoded = PlaceBackup.decode(exported.json, now: now);
      expect(decoded.places.first.sound, AlertSound.fallback);
      expect(decoded.places.last.sound, const PresetSound(SoundPreset.bell));
    });

    test('파일에 좌표 외의 식별 정보(id)가 없다', () {
      final exported = PlaceBackup.encode([place(id: 'secret-id')], now: now);

      expect(exported.json, isNot(contains('secret-id')));
    });
  });

  group('깨진 파일', () {
    test('JSON 이 아니면 notJson', () {
      expect(
        PlaceBackup.decode('안녕', now: now).error,
        PlaceBackupError.notJson,
      );
    });

    test('다른 앱의 JSON 이면 notBackup', () {
      expect(
        PlaceBackup.decode(file([], format: 'other'), now: now).error,
        PlaceBackupError.notBackup,
      );
      expect(
        PlaceBackup.decode('[1,2]', now: now).error,
        PlaceBackupError.notBackup,
      );
    });

    test('더 새 버전의 파일은 읽지 않는다', () {
      expect(
        PlaceBackup.decode(file([], version: 99), now: now).error,
        PlaceBackupError.newerVersion,
      );
    });

    test('장소 하나가 깨져도 나머지는 읽고 건너뛴 수를 센다', () {
      final decoded = PlaceBackup.decode(
        file([
          raw(name: '정상'),
          raw(name: '', radius: 100), // 이름 없음
          raw(radius: 10), // 반경 범위 밖
          raw(lat: 123), // 위도 범위 밖
          raw(radius: '큼'), // 형식이 다름
          'x',
        ]),
        now: now,
      );

      expect(decoded.error, isNull);
      expect(decoded.places.map((p) => p.name), ['정상']);
      expect(decoded.invalidCount, 5);
    });

    test('시간 창이 깨진 장소는 버린다 — 창만 빠지면 밤에도 울린다', () {
      final broken = raw()
        ..['schedules'] = [
          {
            'days': [9],
            'start': 0,
            'end': 10,
          },
        ];

      final decoded = PlaceBackup.decode(file([broken]), now: now);

      expect(decoded.places, isEmpty);
      expect(decoded.invalidCount, 1);
    });

    test('모르는 방향·알림음은 기본값으로 흡수한다', () {
      final item = raw()
        ..['direction'] = '???'
        ..['sound'] = 'custom:abc';

      final decoded = PlaceBackup.decode(file([item]), now: now).places.single;

      expect(decoded.direction, AlertDirection.enter);
      expect(decoded.sound, AlertSound.fallback);
    });
  });

  group('합치기 계획', () {
    test('같은 이름·같은 자리는 건너뛴다 — 두 번 불러와도 두 배가 되지 않는다', () {
      final existing = [place()];
      final incoming = [place(id: 'n'), place(id: 'm', name: '집')];

      final plan = PlaceBackup.plan(
        existing: existing,
        incoming: incoming,
        replace: false,
      );

      expect(plan.toAdd.map((p) => p.name), ['집']);
      expect(plan.duplicateCount, 1);
    });

    test('이름이 같아도 자리가 멀면 다른 장소다', () {
      final plan = PlaceBackup.plan(
        existing: [place()],
        incoming: [place(id: 'n', latitude: 37.6)],
        replace: false,
      );

      expect(plan.toAdd, hasLength(1));
    });

    test('등록 상한 20개를 넘기지 않는다', () {
      final existing = [
        for (var i = 0; i < 19; i++)
          place(id: 'e$i', name: 'e$i', latitude: 30 + i * 0.1),
      ];
      final incoming = [
        place(id: 'a', name: 'a', latitude: 10),
        place(id: 'b', name: 'b', latitude: 11),
        place(id: 'c', name: 'c', latitude: 12),
      ];

      final plan = PlaceBackup.plan(
        existing: existing,
        incoming: incoming,
        replace: false,
      );

      expect(plan.toAdd, hasLength(1));
      expect(plan.overLimitCount, 2);
    });

    test('모두 바꾸기는 기존 목록을 보지 않는다', () {
      final plan = PlaceBackup.plan(
        existing: [place()],
        incoming: [place(id: 'n')],
        replace: true,
      );

      expect(plan.toAdd, hasLength(1));
      expect(plan.duplicateCount, 0);
    });
  });
}
