import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱바 없는 화면의 상태바 아이콘색을 테마 밝기에 맞춘다 (이슈 #272)
///
/// 상태바 색은 `AppBarTheme.systemOverlayStyle` 이 앱바가 있는 화면에서만
/// 정한다. 지도 홈·온보딩처럼 앱바가 없으면 마지막 화면의 값이 남아,
/// 라이트 모드에서 흰 아이콘이 밝은 바탕에 묻혔다.
class ThemedStatusBar extends StatelessWidget {
  const ThemedStatusBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: child,
    );
  }
}
