import 'dart:io';

/// 장소 등록 상한 단일 원본: 등급별(무료·프로) + 플랫폼별 OS 한도 (#294)
/// 등록 검증·감시 동기화·백업 가져오기·화면 표기가 모두 여기를 읽는다
abstract final class PlaceLimits {
  /// 무료 등급 장소 수
  static const int freePlaces = 1;

  /// Android 프로 상한 — OS 지오펜스 100개 / 장소당 원 3개(GeofenceRegistrar.kt) 에서 여유를 둔 값
  static const int androidProPlaces = 30;

  /// iOS 상한 — OS 영역 감시 20개 제한 (docs/05-PLATFORM.md)
  static const int iosPlaces = 20;

  /// 플랫폼 OS 한도 (등급 무관). 백그라운드 isolate 에서도 호출 가능
  static int platformMaximum() =>
      Platform.isAndroid ? androidProPlaces : iosPlaces;
}
