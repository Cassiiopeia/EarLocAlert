import 'dart:async';
import 'dart:io';

import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:ear_loc_alert/features/places/data/current_location_channel.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/presentation/place_list_controller.dart';
import 'package:ear_loc_alert/features/places/presentation/place_map_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 홈 상단 상태 알약이 좁은 폰에서도 넘치지 않는다 (#278)
///
/// **실제 앱 글꼴(Pretendard)을 불러와서 잰다.** 테스트 기본 글꼴은 글자마다
/// 정사각형이라 실제보다 훨씬 넓다 — 그 폭으로 재면 앱에 없는 넘침을 본다.
/// 로고도 디코딩을 끝낸 뒤 잰다 — 디코딩 전에는 폭이 0 이라 넘침을 놓친다.
Future<void> _loadPretendard() async {
  final loader = FontLoader('Pretendard');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File(
      'assets/fonts/pretendard/Pretendard-$weight.otf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _decodeLogo(WidgetTester tester) => tester.runAsync(() async {
  final done = Completer<void>();
  const AssetImage('assets/icon/app_logo_mark.png')
      .resolve(ImageConfiguration.empty)
      .addListener(ImageStreamListener((_, _) => done.complete()));
  await done.future;
});

void main() {
  setUpAll(_loadPretendard);

  for (final (locale, width) in [
    ('en', 320.0),
    ('ko', 320.0),
    ('ja', 320.0),
    ('zh', 320.0),
  ]) {
    testWidgets('$locale · 폭 $width 에서 감시 중·진동만 알약이 넘치지 않는다', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _decodeLogo(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeListProvider.overrideWith(
              (ref) => Stream.value(const <AlertPlace>[]),
            ),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark(),
            home: PlaceMapHomeScreen(
              isMonitoring: true,
              isStatusKnown: true,
              isHeadphoneConnected: false,
              onAddPlace: () {},
              onOpenSettings: () {},
              locationService: const UnavailableCurrentLocationService(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  }
}
