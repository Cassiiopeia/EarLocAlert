import '../../../core/diagnostics/diagnostics.dart';

/// 앱 내 업데이트 (이슈 #170)
///
/// Google Play 의 앱 내 업데이트로 새 버전을 앱 안에서 받는다. **유연한 방식만
/// 쓴다** — 백그라운드로 받고 다 받으면 재시작을 안내한다. 화면을 막는 즉시
/// 방식은 알림을 해제해야 하는 이 앱과 맞지 않는다.
///
/// **이 인터페이스의 메서드는 예외를 던지지 않는다.** 업데이트는 부가 기능이고
/// Play 밖에서 설치한 빌드(개발 빌드·직접 받은 APK)에서는 확인이 실패하는 것이
/// 정상이다 (docs/02-ARCHITECTURE.md 규칙 4).
abstract interface class AppUpdater {
  /// 이 플랫폼에서 앱 내 업데이트가 되는가 (이슈 #229).
  /// iOS 는 앱 내 업데이트가 없어 `false` — 화면이 확인 버튼을 숨기는 근거다
  bool get isSupported;

  /// 새 버전을 받을 수 있는가. 모르면(확인 실패) `false`.
  Future<bool> updateAvailable();

  /// 백그라운드로 내려받는다. 다 받았으면 `true`.
  Future<bool> download();

  /// 받아 둔 버전을 설치하고 앱을 다시 시작한다.
  Future<void> install();
}

/// 확인 결과. 화면은 [downloaded] 일 때만 안내를 띄운다.
enum AppUpdateOutcome {
  /// 알림이 울리는 중이라 건너뛰었다.
  skippedAlertActive,

  /// 방금 확인했다.
  skippedRecent,

  /// 새 버전이 없거나 확인하지 못했다.
  none,

  /// 새 버전을 받아 두었다. 재시작하면 적용된다.
  downloaded,
}

/// 확인해도 될 때만 확인한다 (이슈 #170)
///
/// **알림이 울리는 중에는 확인도 안내도 하지 않는다.** 안내가 알림 화면 위에
/// 올라오면 해제 버튼이 가려진다 — 광고 동의(#166)와 같은 이유다. 또 앞으로 나올
/// 때마다 물으면 Play 요청만 늘어서 [minInterval] 간격을 둔다.
class AppUpdateGate {
  AppUpdateGate(
    this._updater, {
    this.minInterval = const Duration(hours: 6),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppUpdater _updater;
  final Duration minInterval;
  final DateTime Function() _now;

  DateTime? _lastCheck;

  /// 이 플랫폼에서 확인할 수 있는가 (이슈 #229). 아니면 확인 버튼을 두지 않는다 —
  /// 눌러도 아무 반응이 없는 버튼은 고장으로 읽힌다
  bool get isSupported => _updater.isSupported;

  /// [force] 는 사용자가 설정에서 직접 눌렀을 때다 — 간격 제한만 건너뛴다.
  /// 알림이 울리는 중에는 누른 경우에도 확인하지 않는다 (안내가 해제 버튼을 가린다).
  Future<AppUpdateOutcome> checkWhenIdle({
    required bool Function() alertActive,
    bool force = false,
  }) async {
    if (alertActive()) {
      Diagnostics.log('update', 'check skipped reason=alert_active');
      return AppUpdateOutcome.skippedAlertActive;
    }
    final last = _lastCheck;
    if (!force && last != null && _now().difference(last) < minInterval) {
      return AppUpdateOutcome.skippedRecent;
    }
    _lastCheck = _now();

    if (!await _updater.updateAvailable()) return AppUpdateOutcome.none;
    // 받는 동안 알림이 울렸을 수 있다 — 안내는 다시 확인하고 낸다
    if (!await _updater.download()) return AppUpdateOutcome.none;
    if (alertActive()) {
      Diagnostics.log('update', 'notice skipped reason=alert_active');
      return AppUpdateOutcome.skippedAlertActive;
    }
    return AppUpdateOutcome.downloaded;
  }

  /// 안내에서 재시작을 눌렀을 때.
  Future<void> install() => _updater.install();
}
