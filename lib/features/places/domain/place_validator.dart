/// 장소 입력 검증 (docs/01-REQUIREMENTS.md F1)
///
/// 순수 로직 — 화면 없이 테스트한다.
enum PlaceValidationError {
  /// 이름이 비어 있다
  emptyName,

  /// 반경이 허용 범위(50~2000m)를 벗어났다 (F1.4)
  radiusOutOfRange,

  /// 좌표가 유효 범위를 벗어났다
  invalidCoordinates,

  /// 등록 상한에 도달했다 — iOS OS 제한 20개 (docs/05-PLATFORM.md)
  limitReached,
}

abstract final class PlaceValidator {
  static const int minRadiusMeters = 50;
  static const int maxRadiusMeters = 2000;

  /// iOS 지오펜스 상한. **OS 제한이며 우회 방법이 없다.**
  /// 플랫폼 공통으로 같은 상한을 적용한다 — 기기를 바꿔도 동작이 같아야 한다.
  static const int maxPlaces = 20;

  static List<PlaceValidationError> validate({
    required String name,
    required int radiusMeters,
    required double latitude,
    required double longitude,
    required int currentCount,

    /// 수정이면 상한 검사를 건너뛴다 — 이미 등록된 장소다
    required bool isNew,
  }) {
    return [
      if (name.trim().isEmpty) PlaceValidationError.emptyName,
      if (radiusMeters < minRadiusMeters || radiusMeters > maxRadiusMeters)
        PlaceValidationError.radiusOutOfRange,
      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180)
        PlaceValidationError.invalidCoordinates,
      if (isNew && currentCount >= maxPlaces) PlaceValidationError.limitReached,
    ];
  }
}
