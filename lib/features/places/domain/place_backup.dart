import 'dart:convert';
import 'dart:math' as math;

import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';
import '../../../core/domain/alert_sound.dart';
import '../../../core/domain/vibration_pattern.dart';
import '../../../core/domain/id_generator.dart';
import '../../../core/entitlement/place_limits.dart';
import 'alert_place.dart';
import 'place_validator.dart';

/// 장소 내보내기·불러오기 파일 (이슈 #256)
///
/// **서버 없이 기기를 옮기는 가장 단순한 길이다.** 장소 이름·좌표·반경을
/// 다시 입력하지 않게 JSON 한 파일로 주고받는다. 순수 로직이라 화면 없이
/// 테스트한다.
///
/// 파일에 `schemaVersion` 을 둔다 — 장소 모양이 바뀌어도 옛 파일을 읽고,
/// 이 앱보다 새 파일이면 읽지 않고 알린다.
abstract final class PlaceBackup {
  /// 우리 파일임을 알아보는 표식. 다른 앱의 JSON 을 잘못 불러오지 않게 한다
  static const formatName = 'earlocalert-places';

  /// 지금 쓰고 읽는 모양의 버전
  static const schemaVersion = 1;

  /// [places] 를 파일 내용으로 만든다.
  ///
  /// **id·createdAt 은 넣지 않는다.** 불러올 때 새로 만든다 — 같은 파일을
  /// 두 번 불러오거나 다른 기기에서 불러와도 식별자가 겹치지 않는다.
  ///
  /// 사용자가 등록한 음원(`custom:`)은 파일에 담지 못한다. 가리키는 음원이
  /// 다른 기기에는 없어 알림이 조용해질 수 있으므로 기본음으로 바꿔 적는다.
  static PlaceBackupExport encode(
    List<AlertPlace> places, {
    required DateTime now,
    String? appVersion,
  }) {
    var customSounds = 0;
    final items = <Map<String, Object?>>[];
    for (final place in places) {
      final sound = place.sound;
      if (sound is CustomSoundRef) customSounds++;
      items.add({
        'name': place.name,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'radiusMeters': place.radiusMeters,
        'direction': place.direction.name,
        'enabled': place.enabled,
        'soundEnabled': place.soundEnabled,
        'sound': sound is CustomSoundRef
            ? AlertSound.fallback.storageValue
            : sound.storageValue,
        // 선택 필드 (#311): 없으면 기본 패턴 따름
        if (place.vibrationPattern != null)
          'vibrationPattern': place.vibrationPattern!.name,
        'schedules': [
          for (final schedule in place.schedules)
            {
              'days': (schedule.daysOfWeek.toList()..sort()),
              'start': schedule.startMinuteOfDay,
              'end': schedule.endMinuteOfDay,
            },
        ],
      });
    }

    final json = const JsonEncoder.withIndent('  ').convert({
      'format': formatName,
      'schemaVersion': schemaVersion,
      'exportedAt': now.toUtc().toIso8601String(),
      if (appVersion != null) 'appVersion': appVersion,
      'places': items,
    });
    return PlaceBackupExport(
      json: json,
      placeCount: places.length,
      customSoundCount: customSounds,
    );
  }

  /// 파일 내용을 읽는다. **절대 던지지 않는다** — 깨진 파일은 [PlaceBackupError]
  /// 로 돌려주고, 장소 하나가 깨졌으면 그것만 세어 건너뛴다.
  static PlaceBackupDecoded decode(String raw, {required DateTime now}) {
    final Object? root;
    try {
      root = jsonDecode(raw);
    } on FormatException {
      return const PlaceBackupDecoded.failure(PlaceBackupError.notJson);
    }
    if (root is! Map<String, Object?> || root['format'] != formatName) {
      return const PlaceBackupDecoded.failure(PlaceBackupError.notBackup);
    }
    final version = root['schemaVersion'];
    if (version is! int) {
      return const PlaceBackupDecoded.failure(PlaceBackupError.notBackup);
    }
    // 새 버전의 파일은 모르는 필드가 있을 수 있다 — 잘못 읽느니 읽지 않는다
    if (version > schemaVersion) {
      return const PlaceBackupDecoded.failure(PlaceBackupError.newerVersion);
    }
    final list = root['places'];
    if (list is! List<Object?>) {
      return const PlaceBackupDecoded.failure(PlaceBackupError.notBackup);
    }

    final places = <AlertPlace>[];
    var invalid = 0;
    for (final item in list) {
      final place = _decodePlace(item, now);
      if (place == null) {
        invalid++;
      } else {
        places.add(place);
      }
    }
    return PlaceBackupDecoded._(places: places, invalidCount: invalid);
  }

  /// 장소 하나를 읽는다. 검증을 통과하지 못하면 null — 좌표가 범위 밖이거나
  /// 반경이 허용 범위 밖인 장소를 저장소에 들이지 않는다
  static AlertPlace? _decodePlace(Object? item, DateTime now) {
    if (item is! Map<String, Object?>) return null;

    final name = item['name'];
    final latitude = item['latitude'];
    final longitude = item['longitude'];
    final radius = item['radiusMeters'];
    if (name is! String ||
        latitude is! num ||
        longitude is! num ||
        radius is! int) {
      return null;
    }

    final schedules = <AlertSchedule>[];
    final rawSchedules = item['schedules'];
    if (rawSchedules is List<Object?>) {
      for (final raw in rawSchedules) {
        final schedule = _decodeSchedule(raw);
        // 창 하나가 깨졌으면 장소 전체를 버린다 — 그 창만 빠지면 시간 제한이
        // 사라져 밤에도 울린다
        if (schedule == null) return null;
        schedules.add(schedule);
      }
    }

    final errors = PlaceValidator.validate(
      name: name,
      radiusMeters: radius,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      currentCount: 0,
      // 수정 취급이라 상한 검사 안 함 — 상한은 plan() 이 본다
      maxPlaces: PlaceLimits.platformMaximum(),
      isNew: false,
      schedules: schedules,
    );
    if (errors.isNotEmpty) return null;

    final directionName = item['direction'];
    final direction = AlertDirection.values.firstWhere(
      (value) => value.name == directionName,
      orElse: () => AlertDirection.enter,
    );
    final sound = item['sound'];

    return AlertPlace(
      id: IdGenerator.generate(),
      name: name.trim(),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      radiusMeters: radius,
      direction: direction,
      enabled: item['enabled'] is bool ? item['enabled'] as bool : true,
      soundEnabled: item['soundEnabled'] is bool
          ? item['soundEnabled'] as bool
          : true,
      // 깨진 값은 parse 가 기본음으로 떨어뜨린다. 파일에 custom 이 와도
      // 이 기기에는 음원이 없으므로 기본음으로 바꾼다
      sound: sound is String && AlertSound.parse(sound) is PresetSound
          ? AlertSound.parse(sound)
          : AlertSound.fallback,
      // 없거나 모르는 이름은 기본 패턴 따름 (#311)
      vibrationPattern: item['vibrationPattern'] is String
          ? VibrationPattern.tryParse(item['vibrationPattern'] as String)
          : null,
      schedules: schedules,
      createdAt: now.toUtc(),
    );
  }

  static AlertSchedule? _decodeSchedule(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final days = raw['days'];
    final start = raw['start'];
    final end = raw['end'];
    if (days is! List<Object?> || start is! int || end is! int) return null;
    if (days.any((day) => day is! int || day < 1 || day > 7)) return null;
    if (start < 0 || start > 1439 || end < 0 || end > 1439) return null;
    return AlertSchedule(
      daysOfWeek: {for (final day in days) day as int},
      startMinuteOfDay: start,
      endMinuteOfDay: end,
    );
  }

  /// 불러올 장소를 기존 목록과 맞춰 넣을 것·건너뛸 것으로 나눈다.
  ///
  /// [replace] 면 기존 장소를 전부 지우고 가져오는 경우라 기존 목록과 겹침을
  /// 보지 않고, 상한은 빈 목록 기준이다.
  static PlaceImportPlan plan({
    required List<AlertPlace> existing,
    required List<AlertPlace> incoming,
    required bool replace,

    /// 등록 상한 — `FeatureAccess.placeLimit` (#294)
    required int maxPlaces,
  }) {
    final base = replace ? const <AlertPlace>[] : existing;
    final seen = [...base];
    final toAdd = <AlertPlace>[];
    var duplicates = 0;
    var overLimit = 0;
    for (final place in incoming) {
      if (seen.any((other) => _isSamePlace(other, place))) {
        duplicates++;
        continue;
      }
      if (seen.length >= maxPlaces) {
        overLimit++;
        continue;
      }
      seen.add(place);
      toAdd.add(place);
    }
    return PlaceImportPlan(
      toAdd: toAdd,
      duplicateCount: duplicates,
      overLimitCount: overLimit,
    );
  }

  /// 이름이 같고 좌표가 1m 안쪽이면 같은 장소로 본다.
  /// 같은 파일을 두 번 불러와도 장소가 두 배가 되지 않게 한다
  static bool _isSamePlace(AlertPlace a, AlertPlace b) {
    if (a.name.trim().toLowerCase() != b.name.trim().toLowerCase()) {
      return false;
    }
    const metersPerDegree = 111320.0;
    final dLat = (a.latitude - b.latitude) * metersPerDegree;
    final dLon =
        (a.longitude - b.longitude) *
        metersPerDegree *
        math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLon * dLon) <= 1;
  }
}

/// 파일 내용과, 담지 못해 바꾼 것의 수
class PlaceBackupExport {
  const PlaceBackupExport({
    required this.json,
    required this.placeCount,
    required this.customSoundCount,
  });

  final String json;
  final int placeCount;

  /// 사용자 음원이라 기본음으로 바꿔 적은 장소 수
  final int customSoundCount;
}

enum PlaceBackupError {
  /// JSON 이 아니다
  notJson,

  /// JSON 이지만 이 앱의 장소 파일이 아니다
  notBackup,

  /// 더 새 버전의 앱이 만든 파일이다
  newerVersion,
}

class PlaceBackupDecoded {
  const PlaceBackupDecoded._({required this.places, required this.invalidCount})
    : error = null;

  const PlaceBackupDecoded.failure(PlaceBackupError this.error)
    : places = const [],
      invalidCount = 0;

  final PlaceBackupError? error;

  /// 새 id 가 붙은, 저장할 수 있는 장소
  final List<AlertPlace> places;

  /// 검증을 통과하지 못해 건너뛴 항목 수
  final int invalidCount;
}

class PlaceImportPlan {
  const PlaceImportPlan({
    required this.toAdd,
    required this.duplicateCount,
    required this.overLimitCount,
  });

  final List<AlertPlace> toAdd;

  /// 같은 장소가 이미 있어 건너뛴 수
  final int duplicateCount;

  /// 등록 상한(20개)에 걸려 건너뛴 수
  final int overLimitCount;
}
