import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/places/data/current_location_channel.dart';
import 'package:ear_loc_alert/features/places/presentation/place_map_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 중앙 고정 핀의 끝이 저장될 좌표(지도 중심)를 가리키는가 (이슈 #152)
///
/// **핀은 지도 마커가 아니라 화면에 고정된 오버레이다.** 어긋나면
/// 상황과 무관하게 항상 같은 만큼 어긋나고, 사용자가 찍은 곳이 아닌
/// 좌표가 저장된다. padding 제거로 54px 은 없앴지만 글리프 여백 때문에
/// 실기기에서 10px(4dp)이 남아 있었다.
void main() {
  testWidgets('핀 끝이 지도 중심에 온다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const PlaceMapPickerScreen(
          args: MapPickArgs(radiusMeters: 100),
          locationService: UnavailableCurrentLocationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapCenter = tester.getRect(find.byType(GoogleMap)).center;

    final pin = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.place_outlined && w.size == 40,
    );
    final pinBox = tester.getRect(pin);
    // place_outlined 의 끝은 24 격자에서 y=22 — 상자 바닥보다 2/24 위다
    final tipY = pinBox.bottom - pinBox.height * 2 / 24;

    expect(pinBox.center.dx, closeTo(mapCenter.dx, 0.5));
    expect(
      tipY,
      closeTo(mapCenter.dy, 0.5),
      reason: '핀 끝과 저장 좌표가 어긋나면 사용자가 찍은 곳이 아닌 자리가 저장된다',
    );
  });
}
