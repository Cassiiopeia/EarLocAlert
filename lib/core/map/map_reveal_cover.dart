import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../diagnostics/diagnostics.dart';
import '../theme/app_colors.dart';

/// 지도 타일이 그려지기 전의 밝은 바탕을 가린다 (이슈 #143)
///
/// 콜드 스타트마다 지도 영역이 2~3초 **밝은 베이지**로 보였다가 어두워졌다.
/// 스타일 적용 실패가 아니라 타일을 받기 전 Maps SDK 의 기본 바탕이다 —
/// 다크 스타일은 타일에만 먹는다. SDK 에는 이 바탕색을 정하는 옵션이
/// 있지만 Flutter 플러그인이 열어두지 않았고, "다 그렸다"는 신호도 없다.
///
/// 그래서 **지도를 찍어 본다.** 만든 직후 짧은 간격으로 스냅샷을 찍어
/// 어두워졌으면 걷는다. 32px 로 줄여 디코드하므로 가볍고, 상한이 지나면
/// 무조건 걷는다 — 덮개가 지도를 영영 가리면 그쪽이 더 나쁘다.
///
/// 덮개 색은 다크 스타일 바탕(`#0d0d0d`)과 같다 — 걷힐 때 이음매가 없다.
class MapRevealCover extends StatefulWidget {
  const MapRevealCover({
    required this.screen,
    required this.builder,
    this.snapshot,
    super.key,
  });

  /// 로그에 남길 화면 이름 — `[map]` 의 다른 기록과 같은 값을 쓴다
  final String screen;

  /// 지도를 만든다. 받은 콜백을 `onMapCreated` 에서 불러야 덮개가 걷힌다
  final Widget Function(void Function(GoogleMapController) attach) builder;

  /// 스냅샷 대체 — 테스트용. 없으면 컨트롤러의 `takeSnapshot` 을 쓴다
  final Future<Uint8List?> Function(GoogleMapController controller)? snapshot;

  static const interval = Duration(milliseconds: 250);
  static const maxWait = Duration(seconds: 4);

  @override
  State<MapRevealCover> createState() => _MapRevealCoverState();
}

class _MapRevealCoverState extends State<MapRevealCover> {
  bool _revealed = false;

  Future<void> _attach(GoogleMapController controller) async {
    final started = DateTime.now();
    final take = widget.snapshot ?? (c) => c.takeSnapshot();
    var tries = 0;
    while (mounted && !_revealed) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed >= MapRevealCover.maxWait) {
        _reveal('시간초과 ${elapsed.inMilliseconds}ms 시도=$tries');
        return;
      }
      await Future<void>.delayed(MapRevealCover.interval);
      tries++;
      try {
        final bytes = await take(controller);
        if (bytes != null && await isMapPainted(bytes)) {
          _reveal(
            '대기=${DateTime.now().difference(started).inMilliseconds}ms '
            '시도=$tries',
          );
          return;
        }
      } on Object catch (error) {
        // 스냅샷을 못 찍는 기기면 기다릴 이유가 없다 — 바로 걷는다
        _reveal('스냅샷 실패 $error');
        return;
      }
    }
  }

  void _reveal(String reason) {
    if (!mounted || _revealed) return;
    Diagnostics.log('map', '첫 타일 표시 화면=${widget.screen} $reason');
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.builder(_attach),
        // 지도 조작을 막지 않는다 — 덮여 있는 동안에도 끌면 움직인다
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _revealed ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: const ColoredBox(color: AppColors.bgBase),
          ),
        ),
      ],
    );
  }
}

/// 지도 스냅샷(PNG)이 다크 타일로 채워졌는가.
///
/// 밝은 픽셀(휘도 180 초과)이 전체의 5% 미만이면 그려진 것으로 본다.
/// 다크 지도의 라벨은 작아서 32px 로 줄이면 이 비율을 넘지 않는다.
Future<bool> isMapPainted(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png, targetWidth: 32);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData();
  frame.image.dispose();
  codec.dispose();
  if (data == null) return false;
  return lightPixelRatio(data) < 0.05;
}

/// RGBA 바이트에서 밝은 픽셀의 비율
double lightPixelRatio(ByteData rgba) {
  final pixels = rgba.lengthInBytes ~/ 4;
  if (pixels == 0) return 1;
  var light = 0;
  for (var i = 0; i < pixels; i++) {
    final r = rgba.getUint8(i * 4);
    final g = rgba.getUint8(i * 4 + 1);
    final b = rgba.getUint8(i * 4 + 2);
    final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
    if (luminance > 180) light++;
  }
  return light / pixels;
}
