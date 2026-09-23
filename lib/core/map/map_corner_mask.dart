import 'package:flutter/material.dart';

/// 지도 카드의 모서리를 둥글게 보이게 한다 (이슈 #142 · #155)
///
/// **`ClipRRect` 가 네이티브 지도 뷰를 자르지 못한다.** 지도는 Flutter 가
/// 그리는 레이어가 아니라 그 위에 합성되는 별도 표면이라, 클립이 걸리지
/// 않고 직사각형으로 남는다. 실기기에서 모서리가 각진 것을 보고 알았다.
///
/// 그래서 자르는 대신 **모서리 바깥을 배경색으로 덮는다.** 카드가 놓인
/// 배경과 같은 색을 넘겨야 자연스럽다.
///
/// 알림 화면과 장소 폼이 함께 쓴다 — 한쪽에만 두면 다른 쪽에서 같은
/// 실수를 다시 한다.
class MapCornerMask extends CustomPainter {
  const MapCornerMask({required this.color, required this.radius});

  /// 카드가 놓인 배경색. 이것이 어긋나면 모서리에 다른 색 테두리가 보인다.
  final Color color;

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds),
      Path()
        ..addRRect(RRect.fromRectAndRadius(bounds, Radius.circular(radius))),
    );
    canvas.drawPath(outside, Paint()..color = color);
  }

  @override
  bool shouldRepaint(MapCornerMask oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
