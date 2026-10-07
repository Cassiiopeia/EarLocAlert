import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/platform/channel_names.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/core/widgets/floating_circle_button.dart';
import 'package:ear_loc_alert/features/places/data/current_location_channel.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/presentation/place_list_controller.dart';
import 'package:ear_loc_alert/features/places/presentation/place_map_home_screen.dart';
import 'package:ear_loc_alert/features/places/presentation/place_map_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "내 위치" 실패 이유에 따라 안내가 갈리는가 (이슈 #227)
///
/// 예전에는 실패가 전부 null 이라 iOS 시간 초과에도 "위치 권한을 확인해주세요"가
/// 떠서 사용자가 멀쩡한 권한 설정을 뒤졌다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 한국어 토스트는 줄바꿈 금지 문자가 끼어 원문으로 못 찾는다 — 영어로 띄워 확인한다
  const permissionText =
      "Can't get your current location. Check the location permission";
  const slowText =
      'Finding your location is taking a while. Try again in a moment';

  group('채널 실패 코드 → 이유', () {
    const channel = MethodChannel(ChannelNames.currentLocation);

    void answer(Future<Object?> Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    }

    test('좌표가 오면 위치를 준다', () async {
      answer((_) async => {'latitude': 37.5, 'longitude': 127.0});
      final result = await const CurrentLocationChannel().current();
      expect(result.location, (latitude: 37.5, longitude: 127.0));
      expect(result.failure, isNull);
    });

    test('permission_denied 는 권한 문제다', () async {
      answer((_) async => throw PlatformException(code: 'permission_denied'));
      final result = await const CurrentLocationChannel().current();
      expect(result.location, isNull);
      expect(result.failure, CurrentLocationFailure.permissionDenied);
    });

    for (final code in ['timeout', 'location_failed', 'no_location']) {
      test('$code 는 측정 실패다 — 권한 안내를 띄우지 않는다', () async {
        answer((_) async => throw PlatformException(code: code));
        final result = await const CurrentLocationChannel().current();
        expect(result.failure, CurrentLocationFailure.measurementFailed);
      });
    }

    test('Android 의 null 결과는 예전 안내(권한)를 유지한다', () async {
      answer((_) async => null);
      final result = await const CurrentLocationChannel().current();
      expect(result.failure, CurrentLocationFailure.permissionDenied);
    });

    test('네이티브 처리기가 없으면 측정 실패다', () async {
      // 처리기를 걸지 않으면 MissingPluginException 이 난다
      final result = await const CurrentLocationChannel().current();
      expect(result.failure, CurrentLocationFailure.measurementFailed);
    });
  });

  group('홈 "내 위치" 버튼', () {
    Future<void> pumpHome(
      WidgetTester tester,
      CurrentLocationFailure failure,
    ) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeListProvider.overrideWith(
              (ref) => Stream.value(const <AlertPlace>[]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark(),
            home: PlaceMapHomeScreen(
              isMonitoring: true,
              isStatusKnown: true,
              isHeadphoneConnected: false,
              onAddPlace: () {},
              onOpenSettings: () {},
              locationService: UnavailableCurrentLocationService(
                failure: failure,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // 테스트 화면에서는 장소 시트가 버튼 위를 덮어 탭이 닿지 않는다 — 버튼 동작을 직접 부른다
      tester
          .widget<FloatingCircleButton>(
            find.widgetWithIcon(
              FloatingCircleButton,
              Icons.my_location_outlined,
            ),
          )
          .onPressed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('권한이 없으면 권한 안내를 띄운다', (tester) async {
      await pumpHome(tester, CurrentLocationFailure.permissionDenied);
      expect(find.text(permissionText), findsOneWidget);
      expect(find.text(slowText), findsNothing);
    });

    testWidgets('측정이 늦으면 다시 눌러달라고 안내한다', (tester) async {
      await pumpHome(tester, CurrentLocationFailure.measurementFailed);
      expect(find.text(slowText), findsOneWidget);
      expect(find.text(permissionText), findsNothing);
    });
  });

  group('위치 선택 화면 "내 위치" 버튼', () {
    Future<void> pumpPicker(
      WidgetTester tester,
      CurrentLocationFailure failure,
    ) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark(),
          home: PlaceMapPickerScreen(
            args: const MapPickArgs(radiusMeters: 100),
            locationService: UnavailableCurrentLocationService(
              failure: failure,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 진입 시 자동 조회는 사용자가 요청한 동작이 아니라 안내하지 않는다
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.byIcon(Icons.my_location_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('실패하면 조용히 넘어가지 않고 안내한다 — 권한', (tester) async {
      await pumpPicker(tester, CurrentLocationFailure.permissionDenied);
      expect(find.text(permissionText), findsOneWidget);
    });

    testWidgets('실패하면 조용히 넘어가지 않고 안내한다 — 측정 지연', (tester) async {
      await pumpPicker(tester, CurrentLocationFailure.measurementFailed);
      expect(find.text(slowText), findsOneWidget);
    });
  });
}
