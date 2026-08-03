import 'geofence_target.dart';

/// OS 지오펜스 등록 동기화 (docs/05-PLATFORM.md)
///
/// 감시는 앱이 폴링하지 않고 **OS 지오펜스에 위임한다**
/// (docs/10-DECISIONS.md 014). 이 인터페이스는 "지금 감시해야 할
/// 대상 집합"을 받아 OS 등록 상태를 거기에 맞추는 책임만 진다 —
/// 이벤트 처리는 백그라운드 콜백(app 계층)이 한다.
abstract interface class GeofenceMonitor {
  /// OS 등록을 [targets] 와 일치시킨다.
  ///
  /// 목록에 없는 기존 등록은 해제하고, 있는 것은 (재)등록한다.
  /// 같은 id 재등록은 덮어쓰기다.
  Future<void> sync(List<GeofenceTarget> targets);

  /// 모든 등록을 해제한다 (감시 전체 중단)
  Future<void> stopAll();

  /// 현재 OS 에 등록된 장소 id 목록
  Future<List<String>> registeredPlaceIds();
}
