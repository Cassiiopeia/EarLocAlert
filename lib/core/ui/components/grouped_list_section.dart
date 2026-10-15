import 'package:flutter/material.dart';

import '../../text/keep_all.dart';
import '../foundation/app_color_palette.dart';
import '../foundation/app_spacing.dart';

/// iOS 설정 앱식 묶음 (이슈 #272)
///
/// 회색 머리글 + 둥근 표면 카드 + 행 사이 가는 선. 화면마다 칸 제목과 목록을
/// 따로 짜면 간격과 선 굵기가 제각각이 된다 — 묶음은 이것 하나로 만든다.
/// 구분선은 아이콘 자리만큼 들여 쓴다 — iOS 목록처럼 글자 줄에 맞춘다.
class GroupedListSection extends StatelessWidget {
  const GroupedListSection({
    this.header,
    this.footer,
    required this.children,
    this.dividerIndent = 56,
    this.headerIndent = AppSpacing.sm,
    super.key,
  });

  final String? header;

  /// 묶음 아래 설명 — 이 묶음이 무엇을 정하는지
  final String? footer;
  final List<Widget> children;
  final double dividerIndent;

  /// 머리글 왼쪽 여백. 설정처럼 목록만 있는 화면은 카드 안쪽 글자에 맞추고(기본),
  /// 폼처럼 다른 칸 제목과 나란한 곳은 0 으로 둔다
  final double headerIndent;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              headerIndent,
              0,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Text(header!, style: context.appTextStyles.caption),
          ),
        // ListTile 의 물결이 둥근 모서리 밖으로 새지 않게 잘라낸다
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Material(
            color: palette.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: dividerIndent,
                      color: palette.separator,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              0,
            ),
            child: Text(
              context.keepAllText(footer!),
              style: context.appTextStyles.caption,
            ),
          ),
      ],
    );
  }
}
