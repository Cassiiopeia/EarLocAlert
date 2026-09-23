import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ear_loc_alert/core/map/map_reveal_cover.dart';
import 'package:flutter_test/flutter_test.dart';

/// 지도 첫 타일 판정 (이슈 #143)
///
/// 콜드 스타트마다 지도가 2~3초 밝은 베이지로 보였다. 덮개는 스냅샷이
/// 어두워졌을 때 걷힌다 — 판정이 틀리면 영영 안 걷히거나 베이지가 샌다.
void main() {
  /// 한 가지 색으로 채운 PNG. [labels] 만큼 흰 점을 찍는다 (다크 지도의 글자)
  Future<Uint8List> png(ui.Color fill, {int labels = 0}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 320, 480),
      ui.Paint()..color = fill,
    );
    final white = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    for (var i = 0; i < labels; i++) {
      canvas.drawRect(
        ui.Rect.fromLTWH((i * 37) % 300.0, (i * 53) % 460.0, 12, 4),
        white,
      );
    }
    final image = await recorder.endRecording().toImage(320, 480);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  testWidgets('타일 전 SDK 기본 바탕(밝은 베이지)은 아직이다', (tester) async {
    await tester.runAsync(() async {
      expect(
        await isMapPainted(await png(const ui.Color(0xFFF1EFE9))),
        isFalse,
      );
    });
  });

  testWidgets('다크 타일은 그려진 것이다 — 라벨 글자가 있어도', (tester) async {
    await tester.runAsync(() async {
      expect(
        await isMapPainted(await png(const ui.Color(0xFF0D0D0D), labels: 12)),
        isTrue,
      );
    });
  });

  test('밝은 픽셀 비율', () {
    // RGBA 네 픽셀 — 밝은 것 하나
    final rgba = ByteData(16)
      ..setUint8(0, 250)
      ..setUint8(1, 250)
      ..setUint8(2, 250);
    expect(lightPixelRatio(rgba), 0.25);
    expect(lightPixelRatio(ByteData(0)), 1, reason: '빈 이미지는 그려지지 않은 것이다');
  });
}
