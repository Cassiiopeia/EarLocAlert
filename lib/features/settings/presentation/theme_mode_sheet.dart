import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_theme_preference.dart';

/// 화면 모드 선택 시트 (이슈 #272)
///
/// 언어 시트와 같은 규칙 — 한 값을 고르는 시트라 고르면 바로 닫히고 적용된다
/// (결정 035). 반환값이 `null` 이면 고르지 않고 닫은 것이다.
Future<AppThemePreference?> showThemeModeSheet(
  BuildContext context, {
  required AppThemePreference current,
}) {
  return showAppBottomSheet<AppThemePreference>(
    context,
    builder: (_) => _ThemeModeSheet(current: current),
  );
}

/// 선택지의 이름 — 설정 줄의 부제에도 쓴다
String themePreferenceLabel(AppLocalizations l10n, AppThemePreference value) =>
    switch (value) {
      AppThemePreference.system => l10n.themeSystem,
      AppThemePreference.light => l10n.themeLight,
      AppThemePreference.dark => l10n.themeDark,
    };

class _ThemeModeSheet extends StatelessWidget {
  const _ThemeModeSheet({required this.current});

  final AppThemePreference current;

  static IconData _icon(AppThemePreference value) => switch (value) {
    AppThemePreference.system => Icons.brightness_auto_outlined,
    AppThemePreference.light => Icons.light_mode_outlined,
    AppThemePreference.dark => Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 알림 화면은 따라오지 않는다는 것을 미리 말한다 — 라이트로 바꿨는데
    // 알림만 어두우면 고장으로 보인다
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.contrast_outlined,
      title: l10n.settingsThemeTitle,
      description: l10n.themeSheetHint,
      body: RadioGroup<AppThemePreference>(
        groupValue: current,
        onChanged: (value) {
          if (value != null) Navigator.of(context).pop(value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in AppThemePreference.values)
              RadioListTile<AppThemePreference>(
                value: value,
                secondary: Icon(_icon(value)),
                title: Text(
                  themePreferenceLabel(l10n, value),
                  style: context.appTextStyles.body,
                ),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}
