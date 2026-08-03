import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

/// 앱 루트 (docs/02-ARCHITECTURE.md)
///
/// 라우터·전역 Provider 는 각 feature 구현과 함께 이 계층에 추가된다.
class EarLocAlertApp extends StatelessWidget {
  const EarLocAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EarLocAlert',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const _PlaceholderScreen(),
    );
  }
}

/// 화면 구현 전 임시 표시 (docs/11-ROADMAP.md Phase 1 진행 중)
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.place_outlined, size: 64),
            const SizedBox(height: 16),
            Text('EarLocAlert', style: AppTypography.screenTitle),
            const SizedBox(height: 8),
            Text('개발 중', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}
