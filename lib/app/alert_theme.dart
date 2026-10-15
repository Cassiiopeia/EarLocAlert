import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 알림 화면은 화면 모드와 무관하게 다크로 그린다 (이슈 #272)
///
/// 밤·대중교통에서 졸다 깨서 보는 화면이다. 라이트 모드라고 갑자기 흰 화면이
/// 뜨면 눈부시고 주변에도 튄다. 알림 화면 지도도 같은 이유로 다크 스타일이다.
Widget alertTheme(Widget child) => Theme(data: AppTheme.dark(), child: child);
