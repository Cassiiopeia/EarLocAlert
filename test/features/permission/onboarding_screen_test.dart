import 'dart:async';

import 'package:ear_loc_alert/core/di/providers.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_kind.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_service.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_snapshot.dart';
import 'package:ear_loc_alert/features/permission/domain/reliability_prompt_store.dart';
import 'package:ear_loc_alert/features/permission/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 권한 조회는 플랫폼 채널이라 테스트에서 반드시 대체한다.
class FakePermissionService implements PermissionService {
  FakePermissionService({this.snapshot = const PermissionSnapshot()});

  final PermissionSnapshot snapshot;

  @override
  Future<PermissionSnapshot> check() async => snapshot;

  @override
  Future<PermissionSnapshot> request(PermissionKind kind) async => snapshot;

  @override
  Future<void> openAppSettings() async {}
}

/// 저장값 읽기가 **권한 조회보다 늦게** 끝나는 저장소 (이슈 #90).
///
/// 실기기에서 `SharedPreferences` 첫 로드는 디스크를 읽으므로 권한 조회보다
/// 늦게 끝날 수 있다. **어느 쪽이 먼저 끝나느냐가 판정을 바꾸면 안 된다** —
/// 이 순서 때문에 신뢰성 권한 안내가 통째로 사라졌던 것이 #90 이다.
class PendingPromptStore implements ReliabilityPromptStore {
  PendingPromptStore({this.seen = false});

  final bool seen;
  final Completer<bool> _read = Completer<bool>();

  bool markSeenCalled = false;

  /// 읽기를 끝낸다 — 테스트가 순서를 직접 정한다
  void completeRead() => _read.complete(seen);

  @override
  Future<bool> wasSeen() => _read.future;

  @override
  Future<void> markSeen() async => markSeenCalled = true;

  @override
  Future<void> reset() async {}
}

/// 권한 온보딩 화면 (이슈 #90)
///
/// 원칙은 둘이고 서로를 배반하지 않는다.
///
/// 1. **묻긴 한다** — 모든 단계는 최소 한 번 화면에 나타난다. 아직 읽지
///    못한 값을 추측해서 단계를 건너뛰지 않는다.
/// 2. **가두지 않는다** — 어느 단계에서든 홈으로 나갈 수 있다. 권한을
///    거부해도 앱 기본 화면에는 도달한다 (A-12, App Store 심사 방침).
void main() {
  const nothingGranted = PermissionSnapshot();

  const essentialsGranted = PermissionSnapshot(
    location: PermissionStatus.granted,
    backgroundLocation: PermissionStatus.granted,
    notification: PermissionStatus.granted,
  );

  const allGranted = PermissionSnapshot(
    location: PermissionStatus.granted,
    backgroundLocation: PermissionStatus.granted,
    notification: PermissionStatus.granted,
    batteryOptimization: PermissionStatus.granted,
    overlay: PermissionStatus.granted,
    fullScreenIntent: PermissionStatus.granted,
  );

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    required PermissionSnapshot permissions,
    required ReliabilityPromptStore store,
    VoidCallback? onFinished,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionServiceProvider.overrideWithValue(
            FakePermissionService(snapshot: permissions),
          ),
          reliabilityPromptStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: OnboardingScreen(onFinished: onFinished),
        ),
      ),
    );
  }

  /// 로딩 중에는 스피너가 돌아 `pumpAndSettle` 이 끝나지 않는다.
  /// 프레임을 손으로 몇 번 돌려 비동기 해결만 반영한다.
  Future<void> settleFrames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  group('묻긴 한다 — 판정은 값이 다 준비된 뒤에', () {
    testWidgets('안내 여부를 아직 읽지 못했으면 완료로 판정하지 않는다', (tester) async {
      final store = PendingPromptStore();
      var finished = false;

      await pumpOnboarding(
        tester,
        permissions: essentialsGranted,
        store: store,
        onFinished: () => finished = true,
      );
      // 권한 조회만 끝나고 저장값은 아직 오지 않은 순간
      await settleFrames(tester);

      expect(
        finished,
        isFalse,
        reason: '읽지 못한 값을 "이미 안내했다"로 추측하면 안내가 통째로 사라진다 (#90)',
      );

      store.completeRead();
      await settleFrames(tester);

      expect(
        find.text('알림을 놓치지 않으려면'),
        findsOneWidget,
        reason: '저장값은 "아직 안내 안 함"이었다 — 안내 단계가 나와야 한다',
      );
      expect(finished, isFalse);
    });

    testWidgets('권한과 안내가 모두 끝난 사용자는 곧장 홈으로 간다', (tester) async {
      final store = PendingPromptStore(seen: true);
      var finished = false;

      await pumpOnboarding(
        tester,
        permissions: allGranted,
        store: store,
        onFinished: () => finished = true,
      );
      store.completeRead();
      await settleFrames(tester);

      expect(finished, isTrue, reason: '끝낸 사용자가 앱을 켤 때마다 완료 화면을 눌러야 하면 통행세다');
    });

    testWidgets('안내를 건너뛰면 다시 묻지 않도록 기록한다', (tester) async {
      final store = PendingPromptStore();

      await pumpOnboarding(
        tester,
        permissions: essentialsGranted,
        store: store,
        onFinished: () {},
      );
      store.completeRead();
      await settleFrames(tester);

      await tester.tap(find.text('나중에 하기'));
      await settleFrames(tester);

      expect(
        store.markSeenCalled,
        isTrue,
        reason: '거절한 사용자에게 켤 때마다 같은 화면을 보이면 통행세다',
      );
    });
  });

  group('가두지 않는다 — 어느 단계에서든 나갈 수 있다 (A-12)', () {
    testWidgets('첫 권한 단계에도 나중에 하기가 있다', (tester) async {
      final store = PendingPromptStore();

      await pumpOnboarding(
        tester,
        permissions: nothingGranted,
        store: store,
        onFinished: () {},
      );
      store.completeRead();
      await settleFrames(tester);

      expect(find.text('위치 권한이 필요합니다'), findsOneWidget);
      expect(
        find.text('나중에 하기'),
        findsOneWidget,
        reason: '권한을 거부해도 앱 기본 화면에는 도달할 수 있어야 한다',
      );
    });

    testWidgets('거부한 상태에서 나중에 하기를 누르면 홈으로 간다', (tester) async {
      const denied = PermissionSnapshot(location: PermissionStatus.denied);
      final store = PendingPromptStore();
      var finished = false;

      await pumpOnboarding(
        tester,
        permissions: denied,
        store: store,
        onFinished: () => finished = true,
      );
      store.completeRead();
      await settleFrames(tester);

      await tester.tap(find.text('나중에 하기'));
      await settleFrames(tester);

      expect(
        finished,
        isTrue,
        reason:
            'iOS 는 한 번 거부하면 다이얼로그를 다시 띄우지 않는다 — '
            '나갈 길이 없으면 사용자가 화면에 갇힌다',
      );
    });

    testWidgets('완료 화면에는 나중에 하기가 없다', (tester) async {
      // 안내 단계를 거쳐 완료에 도달하는 경로다. 처음부터 완료인 사용자는
      // 이 화면을 보지 않고 홈으로 가므로(위 테스트) 여기서는 재현되지 않는다.
      final store = PendingPromptStore();

      await pumpOnboarding(
        tester,
        permissions: essentialsGranted,
        store: store,
        // onFinished 를 주지 않으면 화면에 머물러 다음 단계를 확인할 수 있다
      );
      store.completeRead();
      await settleFrames(tester);

      expect(find.text('알림을 놓치지 않으려면'), findsOneWidget);

      // 건너뛰면 기록이 남아 다음 단계가 완료로 바뀐다
      await tester.tap(find.text('나중에 하기'));
      await settleFrames(tester);

      expect(find.text('준비되었습니다'), findsOneWidget);
      expect(
        find.text('나중에 하기'),
        findsNothing,
        reason: '더 할 것이 없는 화면에 건너뛰기를 두면 무엇을 건너뛰는지 알 수 없다',
      );
    });
  });
}
