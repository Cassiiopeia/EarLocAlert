import 'dart:convert';

import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_document.dart';
import 'package:flutter_test/flutter_test.dart';

// 동기화 파일 모양 (#330): 장소마다 고정 id, 수정 시각, 삭제 표시가 왕복해야 기기 사이 병합이 된다
void main() {
  final updatedAt = DateTime.utc(2026, 11, 5, 10);

  AlertPlace place({String id = 'place-1', AlertSound? sound}) => AlertPlace(
    id: id,
    name: 'Home',
    latitude: 37.5665,
    longitude: 126.978,
    radiusMeters: 150,
    direction: AlertDirection.enter,
    sound: sound ?? const PresetSound(SoundPreset.defaultTone),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  CloudSyncDocument document(List<CloudSyncEntry> entries) => CloudSyncDocument(
    updatedAt: updatedAt,
    deviceLabel: 'Pixel 8',
    entries: entries,
  );

  test(
    'encode then decode keeps syncId updatedAt deleted and place fields',
    () {
      final original = document([
        CloudSyncEntry(syncId: 'place-1', updatedAt: updatedAt, place: place()),
        CloudSyncEntry(
          syncId: 'place-2',
          updatedAt: updatedAt,
          isDeleted: true,
        ),
      ]);

      final decoded = CloudSyncDocument.fromJson(original.toJson());

      expect(decoded, isA<CloudSyncDecodedOk>());
      final result = (decoded as CloudSyncDecodedOk).document;
      expect(result.deviceLabel, 'Pixel 8');
      expect(result.updatedAt, updatedAt);
      expect(result.entries, hasLength(2));
      final kept = result.entries.first;
      expect(kept.syncId, 'place-1');
      expect(kept.isDeleted, isFalse);
      expect(kept.place?.id, 'place-1');
      expect(kept.place?.name, 'Home');
      expect(kept.place?.radiusMeters, 150);
      final deleted = result.entries.last;
      expect(deleted.syncId, 'place-2');
      expect(deleted.isDeleted, isTrue);
      expect(deleted.place, isNull);
    },
  );

  test('custom sound is written as fallback', () {
    final json = document([
      CloudSyncEntry(
        syncId: 'place-1',
        updatedAt: updatedAt,
        place: place(sound: const CustomSoundRef('my-sound')),
      ),
    ]).toJson();

    final decoded = CloudSyncDocument.fromJson(json) as CloudSyncDecodedOk;

    expect(decoded.document.entries.single.place?.sound, AlertSound.fallback);
  });

  test('newer schemaVersion fails with newerSchema', () {
    final raw = jsonEncode({
      'format': CloudSyncDocument.formatName,
      'schemaVersion': CloudSyncDocument.schemaVersion + 1,
      'updatedAt': updatedAt.toIso8601String(),
      'places': <Object>[],
    });

    final decoded = CloudSyncDocument.fromJson(raw);

    expect(decoded, isA<CloudSyncDecodedFailure>());
    expect(
      (decoded as CloudSyncDecodedFailure).error,
      CloudSyncDecodeError.newerSchema,
    );
  });

  test('other format fails with notSyncFile', () {
    final raw = jsonEncode({'format': 'earlocalert-places', 'places': []});

    final decoded = CloudSyncDocument.fromJson(raw) as CloudSyncDecodedFailure;

    expect(decoded.error, CloudSyncDecodeError.notSyncFile);
  });

  test('broken json fails with notJson', () {
    final decoded =
        CloudSyncDocument.fromJson('{not json') as CloudSyncDecodedFailure;

    expect(decoded.error, CloudSyncDecodeError.notJson);
  });

  test('invalid place entry is dropped not fatal', () {
    final raw = jsonEncode({
      'format': CloudSyncDocument.formatName,
      'schemaVersion': CloudSyncDocument.schemaVersion,
      'updatedAt': updatedAt.toIso8601String(),
      'deviceLabel': 'Pixel 8',
      'places': [
        {
          'syncId': 'broken',
          'updatedAt': updatedAt.toIso8601String(),
          'deleted': false,
          'place': {'name': 'No coordinates'},
        },
        {
          'syncId': 'gone',
          'updatedAt': updatedAt.toIso8601String(),
          'deleted': true,
        },
      ],
    });

    final decoded = CloudSyncDocument.fromJson(raw) as CloudSyncDecodedOk;

    expect(decoded.document.entries.map((entry) => entry.syncId), ['gone']);
    expect(decoded.invalidCount, 1);
  });
}
