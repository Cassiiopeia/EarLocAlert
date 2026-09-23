import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/theme/app_spacing.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/places/data/current_location_channel.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/presentation/place_list_controller.dart';
import 'package:ear_loc_alert/features/places/presentation/place_map_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 홈 상단 바 — 상태 알약과 설정 버튼 (이슈 #155)
///
/// **이슈 본문에 적힌 "설정 버튼이 상태 알약의 자식이 아니다" 검사가
/// 레포에 없었다.** 에뮬레이터 QA 에서 설정 버튼의 탭 영역이 38×34dp 로
/// 최소 터치 타깃(48dp)에 못 미치는 것도 함께 나왔다.
void main() {
  const screen = Size(411, 914);

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onOpenSettings,
    VoidCallback? onFixMonitoring,
    bool isMonitoring = true,
    bool isStatusKnown = true,
    List<AlertPlace> places = const [],
  }) async {
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeListProvider.overrideWith((ref) => Stream.value(places)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: PlaceMapHomeScreen(
            isMonitoring: isMonitoring,
            isStatusKnown: isStatusKnown,
            isHeadphoneConnected: false,
            onAddPlace: () {},
            onFixMonitoring: onFixMonitoring,
            onOpenSettings: onOpenSettings ?? () {},
            locationService: const UnavailableCurrentLocationService(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder settingsIcon() => find.byIcon(Icons.settings_outlined);

  /// 보이는 원 — 아이콘을 감싼 가장 가까운 Material
  Rect visibleCircle(WidgetTester tester) => tester.getRect(
    find.ancestor(of: settingsIcon(), matching: find.byType(Material)).first,
  );

  /// 눌리는 범위 — 아이콘을 감싼 가장 바깥 GestureDetector
  Rect hitArea(WidgetTester tester) => tester.getRect(
    find
        .ancestor(of: settingsIcon(), matching: find.byType(GestureDetector))
        .last,
  );

  testWidgets('설정 버튼이 상태 알약의 자식이 아니다', (tester) async {
    await pump(tester);

    final pill = find.ancestor(
      of: find.text('감시 중'),
      matching: find.byType(InkWell),
    );
    expect(pill, findsOneWidget);
    expect(
      find.descendant(of: pill, matching: settingsIcon()),
      findsNothing,
      reason: '알약은 "감시 고장 시 권한 화면" 탭 대상이다 — 그 안에 다른 버튼을 두면 무엇을 누르는지 모호하다',
    );
  });

  testWidgets('설정 버튼의 탭 영역이 48dp 이상이다', (tester) async {
    await pump(tester);

    final hit = hitArea(tester);
    expect(hit.width, greaterThanOrEqualTo(48));
    expect(hit.height, greaterThanOrEqualTo(48));
  });

  testWidgets('보이는 원 바깥 여백을 눌러도 설정이 열린다', (tester) async {
    var opened = 0;
    await pump(tester, onOpenSettings: () => opened++);

    final hit = hitArea(tester);
    final circle = visibleCircle(tester);
    // 원의 왼쪽 위 바깥, 탭 영역 안쪽
    final outside = Offset(
      (hit.left + circle.left) / 2,
      (hit.top + circle.top) / 2,
    );
    expect(circle.contains(outside), isFalse);

    await tester.tapAt(outside);
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('알약과 설정 원은 같은 높이(40)로 선다', (tester) async {
    await pump(tester);

    final pill = tester.getRect(
      find
          .ancestor(of: find.text('감시 중'), matching: find.byType(Material))
          .first,
    );
    expect(pill.height, AppControlSize.floating);
    expect(visibleCircle(tester).height, AppControlSize.floating);
  });

  testWidgets('로고는 옆 아이콘과 같은 높이로 보인다', (tester) async {
    await pump(tester);

    // 예전에는 스플래시 판(여백이 큰 768 판)을 폭 16 으로 넣어 핀이 7dp 로
    // 쪼그라들었다 — 여백 없는 판을 옆 아이콘과 같은 높이로 넣는다
    final logo = tester.widget<Image>(find.byType(Image));
    expect(
      (logo.image as AssetImage).assetName,
      'assets/icon/app_logo_mark.png',
    );
    expect(tester.getSize(find.byType(Image)).height, AppIconSize.inline);
    expect(
      tester.getSize(find.byIcon(Icons.radar_outlined)).height,
      AppIconSize.inline,
    );
  });

  testWidgets('보이는 원은 알약과 같은 여백으로 오른쪽 끝에 선다', (tester) async {
    await pump(tester);

    final circle = visibleCircle(tester);
    final pill = tester.getRect(
      find
          .ancestor(of: find.text('감시 중'), matching: find.byType(Material))
          .first,
    );

    // 탭 영역을 넓힌 만큼 바깥 여백을 뺐으므로 보이는 자리는 그대로다
    expect(screen.width - circle.right, closeTo(pill.left, 0.5));
    expect(circle.center.dy, closeTo(pill.center.dy, 0.5));
  });

  group('감시 상태를 아직 모를 때 (이슈 #142 QA)', () {
    final enabledPlace = AlertPlace(
      id: 'p1',
      name: '회사',
      latitude: 37.5,
      longitude: 127.0,
      radiusMeters: 100,
      direction: AlertDirection.enter,
      createdAt: DateTime.utc(2026),
    );

    testWidgets('"감시 꺼짐" 이 아니라 "확인 중" 이다', (tester) async {
      await pump(
        tester,
        isMonitoring: false,
        isStatusKnown: false,
        places: [enabledPlace],
      );

      expect(find.text('확인 중'), findsOneWidget);
      expect(
        find.text('감시 꺼짐'),
        findsNothing,
        reason: '알림을 끄고 돌아올 때마다 0.5~3초 오경보가 떴다',
      );
    });

    testWidgets('눌러도 권한 화면으로 보내지 않는다', (tester) async {
      var fixed = 0;
      await pump(
        tester,
        isMonitoring: false,
        isStatusKnown: false,
        places: [enabledPlace],
        onFixMonitoring: () => fixed++,
      );

      await tester.tap(find.text('확인 중'));
      await tester.pump();

      expect(fixed, 0);
    });

    testWidgets('확인한 뒤 정말 꺼져 있으면 그대로 "감시 꺼짐" 이다', (tester) async {
      await pump(
        tester,
        isMonitoring: false,
        isStatusKnown: true,
        places: [enabledPlace],
      );

      expect(find.text('감시 꺼짐'), findsOneWidget);
    });
  });
}
