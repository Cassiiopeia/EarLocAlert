import 'package:flutter/widgets.dart';

/// 보이는 모양 바깥까지 탭을 받는다 — 보이는 크기는 그대로 (이슈 #155 QA)
///
/// 머티리얼 FAB 는 **보이는 원 그대로만** 눌린다. 에뮬레이터에서 재 보니
/// 장소 추가·내 위치 버튼은 테두리에서 5dp 만 벗어나도 반응하지 않았다.
/// 이 앱은 버스에서 한 손으로 쓰므로, 흔한 앱들처럼 모양보다 넉넉하게
/// 판정해야 한다. 알림 해제 버튼(#142)·설정 버튼과 같은 방식이다.
///
/// 안쪽 버튼이 자기 탭을 먼저 받고, 바깥 [padding] 에 떨어진 탭만 여기서
/// [onTap] 으로 넘긴다. **넓힌 만큼 바깥 배치 여백에서 빼야** 보이는
/// 위치가 변하지 않는다.
class HitSlop extends StatelessWidget {
  const HitSlop({
    required this.onTap,
    required this.padding,
    required this.child,
    super.key,
  });

  final VoidCallback onTap;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    );
  }
}
