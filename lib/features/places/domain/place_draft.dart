import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';
import '../../../core/domain/alert_sound.dart';
import 'alert_place.dart';

/// 등록·편집 폼의 저장 전 값: 신규 기본값, 저장하지 않은 변경 판정 (이슈 #112)
class PlaceDraft {
  const PlaceDraft({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.hasCoordinateInput,
    required this.radiusMeters,
    required this.direction,
    required this.soundEnabled,
    required this.sound,
    required this.schedules,
  });

  // 신규 등록 기본값 (폼 초기값과 변경 판정이 함께 읽음)
  static const int defaultRadiusMeters = 100;
  static const AlertDirection defaultDirection = AlertDirection.enter;
  static const bool defaultSoundEnabled = true;

  final String name;

  /// 좌표 칸을 숫자로 읽은 값 — 비었거나 숫자가 아니면 null
  final double? latitude;
  final double? longitude;

  /// 좌표 칸에 무엇이든 입력했는가 (숫자가 아니어도 입력은 입력)
  final bool hasCoordinateInput;

  final int radiusMeters;
  final AlertDirection direction;
  final bool soundEnabled;
  final AlertSound sound;
  final List<AlertSchedule> schedules;

  /// 저장하지 않은 변경이 있는가
  ///
  /// 기준 2개: 편집은 원본과 다른가, 신규는 기본값에서 건드렸는가
  /// (빈 폼을 열었다 닫는 것은 버릴 것이 없음)
  bool hasUnsavedChangesFrom(AlertPlace? existing) {
    if (existing == null) {
      return name.trim().isNotEmpty ||
          hasCoordinateInput ||
          schedules.isNotEmpty ||
          radiusMeters != defaultRadiusMeters ||
          direction != defaultDirection ||
          soundEnabled != defaultSoundEnabled ||
          sound != AlertSound.fallback;
    }

    // 좌표는 숫자로 비교 (`37.4` <-> `37.40` 같은 값)
    return name.trim() != existing.name ||
        latitude != existing.latitude ||
        longitude != existing.longitude ||
        radiusMeters != existing.radiusMeters ||
        direction != existing.direction ||
        soundEnabled != existing.soundEnabled ||
        sound != existing.sound ||
        !_isSameScheduleOrder(schedules, existing.schedules);
  }

  /// 시간대 목록 비교 — 순서를 바꾼 것도 변경
  static bool _isSameScheduleOrder(
    List<AlertSchedule> current,
    List<AlertSchedule> original,
  ) {
    if (current.length != original.length) return false;
    for (var index = 0; index < current.length; index++) {
      if (current[index] != original[index]) return false;
    }
    return true;
  }
}
