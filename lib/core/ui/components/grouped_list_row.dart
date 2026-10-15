import 'package:flutter/material.dart';

import '../../text/keep_all.dart';
import '../foundation/app_color_palette.dart';

enum _GroupedListRowTrailing { navigation, toggle, value, custom }

/// 묶음 목록(`GroupedListSection`) 안의 한 줄 — iOS 설정 앱의 셀 (#276)
///
/// 앞 아이콘(보조색) · 제목 · 회색 부제 · 오른쪽 하나. 오른쪽 모양은 생성자
/// 이름으로 고른다. 화면마다 `ListTile` 을 직접 짜면 아이콘 색·부제 줄바꿈이
/// 제각각이 되어, 한 줄은 이것 하나로 그린다.
class GroupedListRow extends StatelessWidget {
  /// 누르면 다음 화면·시트로 간다 — 오른쪽 화살표
  const GroupedListRow.navigation({
    this.icon,
    this.iconColor,
    required this.title,
    this.keepTitleWordsTogether = false,
    this.subtitle,
    this.keepSubtitleWordsTogether = true,
    required this.onTap,
    this.enabled = true,
    super.key,
  }) : _trailing = _GroupedListRowTrailing.navigation,
       toggleValue = false,
       onToggleChanged = null,
       valueText = null,
       customTrailing = null;

  /// 켜고 끈다 — 줄 어디를 눌러도 스위치가 바뀐다
  const GroupedListRow.toggle({
    this.icon,
    this.iconColor,
    required this.title,
    this.keepTitleWordsTogether = false,
    this.subtitle,
    this.keepSubtitleWordsTogether = true,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.enabled = true,
    super.key,
  }) : _trailing = _GroupedListRowTrailing.toggle,
       toggleValue = value,
       onToggleChanged = onChanged,
       onTap = null,
       valueText = null,
       customTrailing = null;

  /// 오른쪽에 지금 값을 보인다 (앱 버전 등)
  const GroupedListRow.value({
    this.icon,
    this.iconColor,
    required this.title,
    this.keepTitleWordsTogether = false,
    this.subtitle,
    this.keepSubtitleWordsTogether = true,
    required this.valueText,
    required this.onTap,
    this.enabled = true,
    super.key,
  }) : _trailing = _GroupedListRowTrailing.value,
       toggleValue = false,
       onToggleChanged = null,
       customTrailing = null;

  /// 오른쪽에 버튼 등 직접 만든 것을 둔다 (업데이트 확인 버튼 등)
  const GroupedListRow.withTrailing({
    this.icon,
    this.iconColor,
    required this.title,
    this.keepTitleWordsTogether = false,
    this.subtitle,
    this.keepSubtitleWordsTogether = true,
    required Widget? trailing,
    this.onTap,
    this.enabled = true,
    super.key,
  }) : _trailing = _GroupedListRowTrailing.custom,
       customTrailing = trailing,
       toggleValue = false,
       onToggleChanged = null,
       valueText = null;

  final IconData? icon;

  /// 아이콘 색. 비우면 보조색 — 권한 허용처럼 상태를 색으로도 보일 때만 준다
  final Color? iconColor;
  final String title;

  /// 제목이 이름이 아니라 **문장**일 때 켠다(장소 폼 소리 칸 설명) — 한국어
  /// 낱말 중간에서 줄이 끊기지 않게 한다. 짧은 이름에는 필요 없다
  final bool keepTitleWordsTogether;
  final String? subtitle;

  /// 부제의 한글 낱말 중간에서 줄이 끊기지 않게 한다. 버전 번호처럼 문장이
  /// 아닌 값이면 끈다 — 보이지 않는 문자가 끼어 값 비교·복사가 어긋난다
  final bool keepSubtitleWordsTogether;
  final VoidCallback? onTap;
  final bool enabled;
  final bool toggleValue;
  final ValueChanged<bool>? onToggleChanged;
  final String? valueText;
  final Widget? customTrailing;
  final _GroupedListRowTrailing _trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final leading = icon == null
        ? null
        : Icon(icon, color: iconColor ?? colors.textSecondary);
    final titleText = Text(
      keepTitleWordsTogether ? context.keepAllText(title) : title,
      style: context.appTextStyles.body,
    );
    final subtitleText = subtitle == null
        ? null
        : Text(
            keepSubtitleWordsTogether
                ? context.keepAllText(subtitle!)
                : subtitle!,
            style: context.appTextStyles.caption,
          );

    if (_trailing == _GroupedListRowTrailing.toggle) {
      return SwitchListTile(
        secondary: leading,
        title: titleText,
        subtitle: subtitleText,
        value: toggleValue,
        onChanged: enabled ? onToggleChanged : null,
      );
    }

    final trailing = switch (_trailing) {
      _GroupedListRowTrailing.navigation => const Icon(
        Icons.chevron_right_outlined,
      ),
      _GroupedListRowTrailing.value => Text(
        valueText ?? '',
        style: context.appTextStyles.body.copyWith(color: colors.textSecondary),
      ),
      _GroupedListRowTrailing.custom => customTrailing,
      _GroupedListRowTrailing.toggle => null,
    };

    return ListTile(
      enabled: enabled,
      leading: leading,
      title: titleText,
      subtitle: subtitleText,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
