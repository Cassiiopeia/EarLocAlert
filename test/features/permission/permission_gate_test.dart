import 'package:ear_loc_alert/features/permission/domain/permission_gate.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_kind.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = PermissionGate();

  group('요청 순서 (docs/05-PLATFORM.md)', () {
    test('아무것도 없으면 사용 중 위치부터 요청한다', () {
      const snapshot = PermissionSnapshot();
      expect(gate.nextStep(snapshot), OnboardingStep.requestLocation);
    });

    test('사용 중 위치를 받으면 항상 위치를 요청한다', () {
      const snapshot = PermissionSnapshot(location: PermissionStatus.granted);
      expect(
        gate.nextStep(snapshot),
        OnboardingStep.requestBackgroundLocation,
        reason: '사용 중 위치 없이 항상 위치를 요청하면 의미가 없다',
      );
    });

    test('위치 둘 다 받으면 알림을 요청한다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.granted,
      );
      expect(gate.nextStep(snapshot), OnboardingStep.requestNotification);
    });

    test('전부 허용되면 done 이다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.granted,
        notification: PermissionStatus.granted,
      );
      expect(gate.nextStep(snapshot), OnboardingStep.done);
    });
  });

  group('거부 상태 처리 (docs/04-CONVENTIONS.md)', () {
    test('denied 는 다시 요청할 수 있다', () {
      const snapshot = PermissionSnapshot(location: PermissionStatus.denied);
      expect(
        gate.nextStep(snapshot),
        OnboardingStep.requestLocation,
        reason: 'denied 는 앱 내 재요청이 통한다',
      );
    });

    test('permanentlyDenied 만 남으면 설정 화면으로 보낸다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.permanentlyDenied,
        backgroundLocation: PermissionStatus.permanentlyDenied,
        notification: PermissionStatus.permanentlyDenied,
      );
      expect(gate.nextStep(snapshot), OnboardingStep.openSettings);
    });

    test('하나가 영구 거부여도 요청 가능한 권한이 남아 있으면 그것을 먼저 한다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.permanentlyDenied,
        notification: PermissionStatus.notRequested,
      );
      expect(
        gate.nextStep(snapshot),
        OnboardingStep.requestBackgroundLocation,
        reason: '하나가 막혔다고 나머지 흐름을 멈추지 않는다',
      );
    });

    test('restricted 는 재요청 대상이 아니다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.restricted,
        backgroundLocation: PermissionStatus.restricted,
        notification: PermissionStatus.restricted,
      );
      expect(gate.nextStep(snapshot), OnboardingStep.done);
    });
  });

  group('온보딩 이탈 허용 (A-12)', () {
    test('전부 허용되면 나갈 수 있다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.granted,
        notification: PermissionStatus.granted,
      );
      expect(gate.canLeaveOnboarding(snapshot), isTrue);
    });

    test('영구 거부 상태에서도 나갈 수 있다 — 사용자를 온보딩에 가두지 않는다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.permanentlyDenied,
        backgroundLocation: PermissionStatus.permanentlyDenied,
        notification: PermissionStatus.permanentlyDenied,
      );
      expect(
        gate.canLeaveOnboarding(snapshot),
        isTrue,
        reason: '앱은 열리고, 무엇이 안 되는지를 화면에 표시한다',
      );
    });

    test('아직 요청할 것이 남아 있으면 나갈 수 없다', () {
      const snapshot = PermissionSnapshot();
      expect(gate.canLeaveOnboarding(snapshot), isFalse);
    });
  });

  group('missing — 부족한 권한 목록', () {
    test('허용된 것은 빠진다', () {
      const snapshot = PermissionSnapshot(location: PermissionStatus.granted);
      expect(gate.missing(snapshot), [
        PermissionKind.backgroundLocation,
        PermissionKind.notification,
      ]);
    });

    test('전부 허용되면 비어 있다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.granted,
        notification: PermissionStatus.granted,
      );
      expect(gate.missing(snapshot), isEmpty);
    });
  });

  group('기능 가능 여부 판정 (F4.5)', () {
    test('위치 둘 다 있어야 백그라운드 감시가 가능하다', () {
      const onlyForeground = PermissionSnapshot(
        location: PermissionStatus.granted,
      );
      expect(onlyForeground.canMonitorInBackground, isFalse);

      const both = PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.granted,
      );
      expect(both.canMonitorInBackground, isTrue);
    });

    test('알림 권한만으로는 감시가 불가능하다', () {
      const snapshot = PermissionSnapshot(
        notification: PermissionStatus.granted,
      );
      expect(snapshot.canMonitorInBackground, isFalse);
      expect(snapshot.canNotify, isTrue);
      expect(snapshot.isComplete, isFalse);
    });
  });
}
