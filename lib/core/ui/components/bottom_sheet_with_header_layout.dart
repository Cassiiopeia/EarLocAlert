import 'package:flutter/material.dart';

import '../../text/keep_all.dart';
import '../foundation/app_color_palette.dart';
import '../foundation/app_spacing.dart';

/// 앱 공통 바텀시트를 띄운다 (#276)
///
/// 손잡이·키보드에 맞춘 높이(`isScrollControlled`)를 늘 같게 켠다. 화면은
/// `showModalBottomSheet` 를 직접 부르지 않는다 — 시트마다 옵션이 달라
/// 어떤 시트는 키보드에 가려지고 어떤 시트는 손잡이가 없었다.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: builder,
  );
}

/// 머리(아이콘·제목·설명)가 있는 바텀시트 틀 (#276)
///
/// - 본문은 스크롤된다 — 글자를 크게 키운 기기에서 넘치지 않는다 (#270 에서 겪음)
/// - 주 버튼은 스크롤 밖 아래 한 자리에 고정된다 (docs/06-UX.md 주 액션 규칙)
/// - 키보드가 올라오면 그 높이만큼 시트 아래가 비워진다
class BottomSheetWithHeaderLayout extends StatelessWidget {
  const BottomSheetWithHeaderLayout({
    this.headerIcon,
    required this.title,
    this.description,
    required this.body,
    this.primaryAction,
    this.secondaryAction,
    super.key,
  });

  /// 제목 앞 아이콘. 문구를 못 읽는 언어가 되어도 무슨 시트인지 알아보게 한다
  final IconData? headerIcon;
  final String title;

  /// 제목 아래 회색 설명 한두 줄
  final String? description;
  final Widget body;

  /// 아래 주 버튼 (보통 FilledButton). 고르면 바로 닫히는 시트는 비운다
  final Widget? primaryAction;

  /// 주 버튼 아래 보조 버튼 (취소 등)
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final hasActions = primaryAction != null || secondaryAction != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  hasActions ? AppSpacing.sm : AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BottomSheetHeader(icon: headerIcon, title: title),
                    if (description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.keepAllText(description!),
                        style: context.appTextStyles.caption,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    body,
                  ],
                ),
              ),
            ),
            if (hasActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?primaryAction,
                    if (primaryAction != null && secondaryAction != null)
                      const SizedBox(height: AppSpacing.xs),
                    ?secondaryAction,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetHeader extends StatelessWidget {
  const _BottomSheetHeader({required this.icon, required this.title});

  final IconData? icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppIconSize.standard),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: Text(title, style: context.appTextStyles.headline)),
      ],
    );
  }
}
