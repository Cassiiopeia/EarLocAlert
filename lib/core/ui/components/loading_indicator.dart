import 'package:flutter/material.dart';

import '../foundation/app_spacing.dart';

/// 자리 전체를 차지하는 가운데 로딩 표시 — 화면·시트 본문을 불러오는 동안
class CenteredLoadingIndicator extends StatelessWidget {
  const CenteredLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// 버튼 앞·검색창 끝에 놓는 작은 로딩 표시 — 글자 옆 아이콘 크기에 맞춘다
class InlineLoadingIndicator extends StatelessWidget {
  const InlineLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: AppIconSize.inline,
    height: AppIconSize.inline,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
