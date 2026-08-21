import 'package:ear_loc_alert/features/permission/domain/permission_kind.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

/// 신뢰성 권한 판정 (이슈 #74, #115)
///
/// 홈 경고 배너가 이 값으로 뜬다. **하나라도 꺼져 있으면 떠야 하고,
/// 무엇이 꺼졌는지 가릴 수 있어야 한다.**
void main() {
  const allGranted = PermissionSnapshot(
    location: PermissionStatus.granted,
    backgroundLocation: PermissionStatus.granted,
    notification: PermissionStatus.granted,
    batteryOptimization: PermissionStatus.granted,
    overlay: PermissionStatus.granted,
    fullScreenIntent: PermissionStatus.granted,
  );

  test('셋 다 허용이면 신뢰할 수 있다', () {
    expect(allGranted.canAlertReliably, isTrue);
  });

  test('배터리 최적화만 꺼져도 신뢰할 수 없다', () {
    final s = allGranted.copyWith(batteryOptimization: PermissionStatus.denied);

    expect(s.canAlertReliably, isFalse);
    expect(s.survivesDoze, isFalse);
    // 나머지는 멀쩡하다 — 배너가 무엇이 꺼졌는지 가려낼 수 있어야 한다
    expect(s.canCoverScreen, isTrue);
    expect(s.canWakeScreen, isTrue);
  });

  test('오버레이만 꺼져도 신뢰할 수 없다', () {
    final s = allGranted.copyWith(overlay: PermissionStatus.denied);

    expect(s.canAlertReliably, isFalse);
    expect(s.canCoverScreen, isFalse);
  });

  test('전체화면만 꺼져도 신뢰할 수 없다', () {
    final s = allGranted.copyWith(
      fullScreenIntent: PermissionStatus.permanentlyDenied,
    );

    expect(s.canAlertReliably, isFalse);
    expect(s.canWakeScreen, isFalse);
  });

  test('신뢰성 권한은 isComplete 에 들어가지 않는다', () {
    // 셋이 없어도 앱은 성립한다 — 알림과 진동으로 동작한다
    // (docs/10-DECISIONS.md 006)
    final s = allGranted.copyWith(
      batteryOptimization: PermissionStatus.denied,
      overlay: PermissionStatus.denied,
      fullScreenIntent: PermissionStatus.denied,
    );

    expect(s.isComplete, isTrue);
    expect(s.canAlertReliably, isFalse);
  });
}
