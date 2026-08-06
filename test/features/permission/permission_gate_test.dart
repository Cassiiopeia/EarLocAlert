import 'package:ear_loc_alert/features/permission/domain/permission_gate.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_kind.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = PermissionGate();

  /// 필수 3종이 전부 허용된 상태 — 신뢰성 권한 테스트의 출발점
  const essentialsGranted = PermissionSnapshot(
    location: PermissionStatus.granted,
    backgroundLocation: PermissionStatus.granted,
    notification: PermissionStatus.granted,
  );

  /// 필수 + 신뢰성 전부 허용
  const allGranted = PermissionSnapshot(
    location: PermissionStatus.granted,
    backgroundLocation: PermissionStatus.granted,
    notification: PermissionStatus.granted,
    batteryOptimization: PermissionStatus.granted,
    overlay: PermissionStatus.granted,
    fullScreenIntent: PermissionStatus.granted,
  );

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

    test('필수 3종이 끝나면 신뢰성 권한을 권한다', () {
      expect(
        gate.nextStep(essentialsGranted),
        OnboardingStep.requestAlertReliability,
        reason: '필수 권한만으로는 백그라운드에서 알림이 끊긴다 (#74)',
      );
    });

    test('신뢰성 권한까지 전부 허용되면 done 이다', () {
      expect(gate.nextStep(allGranted), OnboardingStep.done);
    });
  });

  group('신뢰성 권한은 선택이다 (#74)', () {
    test('이미 권한 적이 있으면 다시 묻지 않는다', () {
      expect(
        gate.nextStep(essentialsGranted, reliabilityPromptSeen: true),
        OnboardingStep.done,
        reason: '거절한 사용자에게 앱을 켤 때마다 같은 화면을 보이면 통행세다',
      );
    });

    test('전부 허용됐으면 권한 적이 없어도 묻지 않는다', () {
      expect(
        gate.nextStep(allGranted, reliabilityPromptSeen: false),
        OnboardingStep.done,
      );
    });

    test('하나라도 빠지면 권한다', () {
      const partial = PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.granted,
        notification: PermissionStatus.granted,
        batteryOptimization: PermissionStatus.granted,
        overlay: PermissionStatus.granted,
        // fullScreenIntent 만 빠졌다
      );
      expect(gate.nextStep(partial), OnboardingStep.requestAlertReliability);
    });

    test('신뢰성 권한 단계에서도 온보딩을 나갈 수 있다', () {
      expect(
        gate.canLeaveOnboarding(essentialsGranted),
        isTrue,
        reason: '선택 권한이 앱 진입을 막으면 안 된다',
      );
    });

    test('필수가 남아 있으면 신뢰성 권한을 먼저 묻지 않는다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.granted,
        overlay: PermissionStatus.granted,
      );
      expect(
        gate.nextStep(snapshot),
        OnboardingStep.requestBackgroundLocation,
        reason: '항상 위치 없이 오버레이만 있어봐야 알릴 것이 없다',
      );
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

    test('필수가 막혀 있으면 신뢰성 권한보다 설정 화면이 먼저다', () {
      const snapshot = PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.permanentlyDenied,
        notification: PermissionStatus.granted,
      );
      expect(
        gate.nextStep(snapshot),
        OnboardingStep.openSettings,
        reason: '항상 위치가 막힌 채로 오버레이를 받아봐야 소용이 없다',
      );
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
      expect(
        gate.nextStep(snapshot, reliabilityPromptSeen: true),
        OnboardingStep.done,
      );
    });
  });

  group('온보딩 이탈 허용 (A-12)', () {
    test('전부 허용되면 나갈 수 있다', () {
      expect(gate.canLeaveOnboarding(allGranted), isTrue);
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

    test('필수가 전부 허용되면 비어 있다 — 신뢰성 권한은 필수가 아니다', () {
      expect(gate.missing(essentialsGranted), isEmpty);
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

  group('알림 신뢰성 판정 (#74)', () {
    test('셋 다 있어야 신뢰성이 확보된다', () {
      expect(allGranted.canAlertReliably, isTrue);
      expect(essentialsGranted.canAlertReliably, isFalse);
    });

    test('오버레이가 없으면 화면을 덮을 수 없다', () {
      const noOverlay = PermissionSnapshot(
        batteryOptimization: PermissionStatus.granted,
        fullScreenIntent: PermissionStatus.granted,
      );
      expect(noOverlay.canCoverScreen, isFalse);

      const withOverlay = PermissionSnapshot(overlay: PermissionStatus.granted);
      expect(withOverlay.canCoverScreen, isTrue);
    });

    test('배터리 최적화 예외가 없으면 절전 중 이벤트가 지연될 수 있다', () {
      const snapshot = PermissionSnapshot(overlay: PermissionStatus.granted);
      expect(snapshot.survivesDoze, isFalse);
    });

    test('신뢰성 권한이 없어도 필수만 있으면 앱은 성립한다', () {
      expect(
        essentialsGranted.isComplete,
        isTrue,
        reason: '신뢰성 권한은 얹는 것이지 전제가 아니다 (docs/10-DECISIONS.md 006)',
      );
    });
  });
}
