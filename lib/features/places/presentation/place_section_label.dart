import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 장소 화면(폼·지도 선택 패널)의 칸 제목 (이슈 #228)
///
/// 위치·알림 반경·알림 시점·시간대·소리 — **모든 칸 제목을 이것 하나로 그린다.**
/// 예전에는 대부분 작은 회색이었는데 소리 칸만 굵은 흰 제목이라 그 칸이 혼자
/// 다른 화면처럼 보였다. 칸마다 `Text(caption)` 을 따로 쓰면 새 칸이 또
/// 어긋나므로 한 곳에서 정한다.
///
/// [trailing] 은 제목 줄 오른쪽에 붙는 현재 값이다 (반경 `100m` 처럼).
class PlaceSectionLabel extends StatelessWidget {
  const PlaceSectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final value = trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(text, style: AppTypography.caption)),
          if (value != null)
            Text(
              value,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
