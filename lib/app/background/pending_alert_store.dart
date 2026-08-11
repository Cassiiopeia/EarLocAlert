import 'package:shared_preferences/shared_preferences.dart';

import '../../core/domain/alert_direction.dart';
import 'pending_alert.dart';

/// PendingAlert 의 isolate 간 전달 저장소 (이슈 #63)
///
/// 쓰는 쪽은 백그라운드 isolate, 읽는 쪽은 메인 isolate 다.
/// SharedPreferences 는 isolate 별로 캐시를 가지므로 **읽기 전
/// reload() 가 필수다** — 없으면 메인 isolate 는 백그라운드가 쓴 값을
/// 영영 못 본다.
///
/// 도메인 데이터가 아니라 일회성 전달 값이라 SharedPreferences 를 쓴다
/// (docs/02-ARCHITECTURE.md 저장소 표 — "단순 설정값").
class PendingAlertStore {
  static const _keyPlaceId = 'pending_alert.place_id';
  static const _keyPlaceName = 'pending_alert.place_name';
  static const _keyDirection = 'pending_alert.direction';
  static const _keySoundEnabled = 'pending_alert.sound_enabled';
  static const _keyOccurredAt = 'pending_alert.occurred_at';

  Future<void> save(PendingAlert alert) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlaceId, alert.placeId);
    await prefs.setString(_keyPlaceName, alert.placeName);
    await prefs.setString(_keyDirection, alert.direction.name);
    await prefs.setBool(_keySoundEnabled, alert.soundEnabled);
    await prefs.setString(
      _keyOccurredAt,
      alert.occurredAt.toUtc().toIso8601String(),
    );
  }

  /// 저장된 알림을 꺼내고 지운다.
  ///
  /// [hadStored] 는 **꺼낼 것이 있었는지**다. 값이 깨져 있어 [alert] 가
  /// null 이어도 true 다 — 네이티브는 그 알림 때문에 진동하고 있으므로,
  /// 읽지 못했다는 이유로 진동을 남겨두면 끌 방법이 없어진다 (이슈 #83).
  Future<({PendingAlert? alert, bool hadStored})> take() async {
    final prefs = await SharedPreferences.getInstance();
    // 백그라운드 isolate 가 쓴 값을 보려면 디스크에서 다시 읽어야 한다
    await prefs.reload();

    final placeId = prefs.getString(_keyPlaceId);
    final placeName = prefs.getString(_keyPlaceName);
    final directionName = prefs.getString(_keyDirection);
    final soundEnabled = prefs.getBool(_keySoundEnabled);
    final occurredAtRaw = prefs.getString(_keyOccurredAt);

    // 아무것도 없으면 지울 것도 없다. 앱이 떠 있는 동안 주기적으로
    // 확인하므로(#74), 빈 상태에서 매번 쓰기를 일으키면 안 된다.
    if (placeId == null && occurredAtRaw == null) {
      return (alert: null, hadStored: false);
    }

    await _clear(prefs);

    if (placeId == null ||
        placeName == null ||
        directionName == null ||
        soundEnabled == null ||
        occurredAtRaw == null) {
      return (alert: null, hadStored: true);
    }

    final direction = AlertDirection.values.asNameMap()[directionName];
    final occurredAt = DateTime.tryParse(occurredAtRaw);
    if (direction == null || occurredAt == null) {
      return (alert: null, hadStored: true);
    }

    return (
      alert: PendingAlert(
        placeId: placeId,
        placeName: placeName,
        direction: direction,
        soundEnabled: soundEnabled,
        occurredAt: occurredAt.toUtc(),
      ),
      hadStored: true,
    );
  }

  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_keyPlaceId);
    await prefs.remove(_keyPlaceName);
    await prefs.remove(_keyDirection);
    await prefs.remove(_keySoundEnabled);
    await prefs.remove(_keyOccurredAt);
  }
}
