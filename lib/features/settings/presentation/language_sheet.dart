import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/foundation/app_color_palette.dart';

/// 앱 언어 선택 시트 (이슈 #163)
///
/// **고르면 바로 적용되고 닫힌다** — 한 값을 고르는 시트는 하단 버튼을 두지
/// 않는다 (결정 035).
///
/// **읽을 수 없는 언어로 바뀌어도 되돌릴 수 있어야 한다.** 그래서 각 언어를
/// **그 언어 자신의 표기로 고정**해 보여준다(한국어, English, 中文, 日本語).
/// 번역하지 않는다. "기기 설정 따르기"는 지구본 아이콘을 함께 두어 문구를 못
/// 읽어도 알아볼 수 있게 한다.
Future<AppLanguage?> showLanguageSheet(
  BuildContext context, {
  required AppLanguage current,
  required String deviceLanguageName,
}) {
  return showAppBottomSheet<AppLanguage>(
    context,
    builder: (context) => _LanguageSheet(
      current: current,
      deviceLanguageName: deviceLanguageName,
    ),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({
    required this.current,
    required this.deviceLanguageName,
  });

  final AppLanguage current;
  final String deviceLanguageName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 문구를 못 읽어도 이 시트가 "언어"임을 알아볼 수 있게 지구본 아이콘을 둔다
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.language_outlined,
      title: l10n.settingsLanguageTitle,
      description: l10n.languageSheetHint,
      body: RadioGroup<AppLanguage>(
        groupValue: current,
        onChanged: (value) {
          if (value != null) Navigator.of(context).pop(value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppLanguage>(
              value: AppLanguage.system,
              secondary: const Icon(Icons.language_outlined),
              title: Text(
                l10n.languageFollowDevice,
                style: context.appTextStyles.body,
              ),
              subtitle: Text(
                l10n.languageFollowDeviceHint(deviceLanguageName),
                style: context.appTextStyles.caption,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            for (final language in AppLanguage.values)
              if (language != AppLanguage.system)
                RadioListTile<AppLanguage>(
                  value: language,
                  // 각 언어의 자기 표기 — 번역하지 않는다
                  title: Text(
                    language.nativeName!,
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
