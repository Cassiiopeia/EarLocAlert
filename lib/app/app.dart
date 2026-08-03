import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

/// 앱 루트 (docs/02-ARCHITECTURE.md)
class EarLocAlertApp extends StatefulWidget {
  const EarLocAlertApp({super.key});

  @override
  State<EarLocAlertApp> createState() => _EarLocAlertAppState();
}

class _EarLocAlertAppState extends State<EarLocAlertApp> {
  // 라우터는 앱 수명 동안 하나만 존재해야 한다 —
  // build 마다 새로 만들면 화면 전환 이력이 초기화된다.
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EarLocAlert',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
