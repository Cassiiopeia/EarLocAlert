import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'locale_resolver.dart';

export 'generated/app_localizations.dart' show AppLocalizations;

/// 화면 문자열 접근 (이슈 #163). 문서가 약속한 `context.l10n.키` 형태다.
///
/// **번역 위임자가 없는 환경에서는 한국어로 떨어진다.** 위젯 테스트가 화면을
/// `MaterialApp` 없이, 또는 위임자 없이 띄우는 경우다. 실제 앱에서는
/// `MaterialApp` 이 항상 위임자를 걸므로 이 폴백은 타지 않는다.
extension AppL10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('ko'));
}

/// **컨텍스트 없이** 문구를 찾는 경로 (이슈 #163).
///
/// 백그라운드 진입점은 UI 없이 돈다 — 여기서 `BuildContext` 를 만질 수 없다
/// (CLAUDE.md 규칙 6). 알림 채널 이름과 "도착했습니다" 같은 문구를 백그라운드가
/// 만들 때 쓴다. **화면과 같은 번역 파일을 읽으므로 문구가 갈리지 않는다.**
class AppStrings {
  const AppStrings._();

  /// [locale] 의 번역을 돌려준다. 지원하지 않는 언어이면 영어다.
  static AppLocalizations forLocale(Locale locale) {
    final supported = supportedAppLocales.any(
      (candidate) => candidate.languageCode == locale.languageCode,
    );
    return lookupAppLocalizations(
      supported ? Locale(locale.languageCode) : fallbackAppLocale,
    );
  }
}
