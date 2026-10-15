import 'package:flutter/material.dart';

import '../foundation/app_color_palette.dart';
import '../foundation/app_spacing.dart';

/// 세그먼트 한 칸
class IconLabelSegment<T> {
  const IconLabelSegment({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final IconData icon;
  final String label;
}

/// iOS 결 세그먼트 선택 (이슈 #272)
///
/// 트랙 위에서 선택한 칸만 한 층 떠오른다. 기본 `SegmentedButton` 은 칸마다
/// 테두리와 체크 표시가 붙어 답답했다. 칸 폭은 같게 두고, 라벨은 줄어들어도
/// 한 줄을 지킨다 — 영어·일본어에서 줄이 바뀌면 높이가 들쭉날쭉해진다.
class IconLabelSegmentedControl<T> extends StatelessWidget {
  const IconLabelSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<IconLabelSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _SegmentCell(
                segment: segment,
                selected: segment.value == selected,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentCell<T> extends StatelessWidget {
  const _SegmentCell({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final IconLabelSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    // 선택 칸은 주색 아이콘 + 굵은 본문색, 나머지는 회색 — 색만으로 가르지 않는다
    final textColor = selected ? palette.textPrimary : palette.textSecondary;
    final iconColor = selected ? palette.accent : palette.textSecondary;
    // 라이트는 흰 칸이 회색 트랙에서 떠 보이고, 다크는 한 층 밝은 칸이 떠 보인다
    final cellColor = Theme.of(context).brightness == Brightness.light
        ? palette.surface
        : palette.separator;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? cellColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.small - 3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(segment.icon, size: AppIconSize.inline, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    softWrap: false,
                    style: context.appTextStyles.body.copyWith(
                      color: textColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
