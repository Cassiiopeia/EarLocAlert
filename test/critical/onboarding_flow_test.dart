import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:ear_loc_alert/features/permission/data/permission_providers.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_kind.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_service.dart';
import 'package:ear_loc_alert/features/permission/domain/permission_snapshot.dart';
import 'package:ear_loc_alert/features/permission/domain/reliability_prompt_store.dart';
import 'package:ear_loc_alert/features/permission/presentation/onboarding/onboarding_checklist_view.dart';
import 'package:ear_loc_alert/features/permission/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 권한 온보딩 흐름 (#376, #379): 필수를 다 허용해야 다음, 나가기 없음, 거부는 설정 열기, 완료 > 첫 장소
/// 테스트 호스트는 Android 가 아니라 iOS 필수 목록(위치·항상 위치·알림)을 탄다

/// 요청하면 [deniedKinds] 는 영구 거부, 나머지는 허용으로 바꾸는 가짜 권한 창구
class _FakePermissionService implements PermissionService {
  _FakePermissionService(this.snapshot, {this.deniedKinds = const {}});

  PermissionSnapshot snapshot;
  final Set<PermissionKind> deniedKinds;
  final List<PermissionKind> requested = [];
  int openSettingsCount = 0;

  @override
  Future<PermissionSnapshot> check() async => snapshot;

  @override
  Future<PermissionSnapshot> request(PermissionKind kind) async {
    requested.add(kind);
    final status = deniedKinds.contains(kind)
        ? PermissionStatus.permanentlyDenied
        : PermissionStatus.granted;
    snapshot = switch (kind) {
      PermissionKind.location => snapshot.copyWith(location: status),
      PermissionKind.backgroundLocation => snapshot.copyWith(
        backgroundLocation: status,
      ),
      PermissionKind.notification => snapshot.copyWith(notification: status),
      PermissionKind.batteryOptimization => snapshot.copyWith(
        batteryOptimization: status,
      ),
      PermissionKind.overlay => snapshot.copyWith(overlay: status),
      PermissionKind.fullScreenIntent => snapshot.copyWith(
        fullScreenIntent: status,
      ),
    };
    return snapshot;
  }

  @override
  Future<void> openAppSettings() async => openSettingsCount++;
}

class _MemoryPromptStore implements ReliabilityPromptStore {
  bool isSeen = false;

  @override
  Future<bool> wasSeen() async => isSeen;

  @override
  Future<void> markSeen() async => isSeen = true;

  @override
  Future<void> reset() async => isSeen = false;
}

void main() {
  late _FakePermissionService service;
  late int finishedCount;
  late int addFirstPlaceCount;

  Future<void> pumpOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    finishedCount = 0;
    addFirstPlaceCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionServiceProvider.overrideWithValue(service),
          reliabilityPromptStoreProvider.overrideWithValue(
            _MemoryPromptStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OnboardingScreen(
            onFinished: () => finishedCount++,
            onAddFirstPlace: () => addFirstPlaceCount++,
          ),
        ),
      ),
    );
    // 그림이 계속 떠 있어 pumpAndSettle 은 끝나지 않음 > 시간만큼 진행
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// 다음 버튼이 눌리는가
  bool isNextEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '다음'))
      .enabled;

  /// 전환 애니메이션이 끝나 나가는 위젯이 빠질 때까지 프레임을 잘게 진행
  /// (그림이 계속 떠 있어 pumpAndSettle 은 끝나지 않음)
  Future<void> settleFrames(WidgetTester tester) async {
    for (var frame = 0; frame < 15; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 화면 밖이면 스크롤해 보이게 한 뒤 누름
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(finder);
    await settleFrames(tester);
  }

  Future<void> tapFirstAllow(WidgetTester tester) =>
      tapVisible(tester, find.text('허용').first);

  testWidgets('필수 3개를 차례로 허용해야 다음이 켜지고, 완료 > 첫 장소 정하기로 이어진다', (tester) async {
    service = _FakePermissionService(const PermissionSnapshot());
    await pumpOnboarding(tester);

    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('나중에 하기'), findsNothing);
    expect(isNextEnabled(tester), isFalse);

    await tapFirstAllow(tester);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('허용됨'), findsOneWidget);
    expect(isNextEnabled(tester), isFalse);

    await tapFirstAllow(tester);
    await tapFirstAllow(tester);
    expect(find.text('3/3'), findsOneWidget);
    expect(service.requested, [
      PermissionKind.location,
      PermissionKind.backgroundLocation,
      PermissionKind.notification,
    ]);
    expect(isNextEnabled(tester), isTrue);

    await tester.tap(find.text('다음'));
    await settleFrames(tester);
    expect(find.text('준비됐어요'), findsOneWidget);

    await tester.tap(find.text('첫 장소 정하기'));
    await tester.pump();
    expect(addFirstPlaceCount, 1);
    expect(finishedCount, 0);
  });

  testWidgets('거부한 항목은 설정 열기로 바뀌고 나가기 없이 다음이 막혀 있다', (tester) async {
    service = _FakePermissionService(
      const PermissionSnapshot(),
      deniedKinds: {PermissionKind.location},
    );
    await pumpOnboarding(tester);

    await tapFirstAllow(tester);
    expect(find.text('설정 열기'), findsOneWidget);
    expect(find.text('나중에 하기'), findsNothing);
    expect(isNextEnabled(tester), isFalse);

    await tapVisible(tester, find.text('설정 열기'));
    expect(service.openSettingsCount, 1);
  });

  testWidgets('항상 위치를 먼저 누르면 사용 중 위치부터 요청한다', (tester) async {
    service = _FakePermissionService(const PermissionSnapshot());
    await pumpOnboarding(tester);

    // 두 번째 줄(항상 위치)의 허용
    await tapVisible(tester, find.text('허용').at(1));
    expect(service.requested, [PermissionKind.location]);
  });

  testWidgets('필수를 이미 다 허용한 재방문 사용자는 곧장 홈으로 간다', (tester) async {
    service = _FakePermissionService(
      const PermissionSnapshot(
        location: PermissionStatus.granted,
        backgroundLocation: PermissionStatus.granted,
        notification: PermissionStatus.granted,
      ),
    );
    await pumpOnboarding(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(finishedCount, 1);
  });

  testWidgets('Android 는 배터리까지 필수 4개다', (tester) async {
    expect(OnboardingChecklistView.requiredKindsFor(isAndroid: true), [
      PermissionKind.location,
      PermissionKind.backgroundLocation,
      PermissionKind.notification,
      PermissionKind.batteryOptimization,
    ]);
    expect(
      OnboardingChecklistView.requiredKindsFor(isAndroid: false),
      isNot(contains(PermissionKind.batteryOptimization)),
    );
  });
}
