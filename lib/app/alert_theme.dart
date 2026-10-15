import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// 알림 화면은 화면 모드와 무관하게 다크로 그린다 (이슈 #272)
///
/// 밤·대중교통에서 졸다 깨서 보는 화면이다. 라이트 모드라고 갑자기 흰 화면이
/// 뜨면 눈부시고 주변에도 튄다. 알림 화면 지도도 같은 이유로 다크 스타일이다.
/// 상태바 아이콘도 늘 밝게 둔다 — 라이트 화면에서 넘어오면 검은 아이콘이
/// 검은 알림 화면 위에 남았다.
Widget alertTheme(Widget child) => AnnotatedRegion<SystemUiOverlayStyle>(
  value: SystemUiOverlayStyle.light,
  child: Theme(data: AppTheme.dark(), child: child),
);

/// 세션이 비었을 때 알림 라우트가 잠깐 보이는 빈 화면.
///
/// 해제 직후 홈으로 옮겨지기 전 한두 프레임 이 화면이 그려진다 — 여기가 루트
/// 테마(라이트)면 해제 순간 흰 판이 번쩍인다 (리뷰 #272).
Widget alertEmptyPlaceholder() =>
    alertTheme(const Scaffold(body: SizedBox.shrink()));
