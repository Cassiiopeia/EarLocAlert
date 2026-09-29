import 'dart:ui';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/app_language_store.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_resolver.dart';

/// 컨텍스트 없이 알림 문구를 찾는다 (이슈 #163)
///
/// 알림 발화 경로는 `BuildContext` 를 만질 수 없다 (CLAUDE.md 규칙 6).
/// 저장된 언어를 **다시 읽어**(isolate 캐시 무효화) 화면과 같은 번역
/// 파일에서 찾는다.
///
/// **문구를 못 찾았다고 알림이 멎으면 안 된다.** 저장소를 못 읽으면 기기
/// 언어로, 그것도 안 되면 영어로 떨어진다 — 이 함수는 던지지 않는다.
Future<AppLocalizations> resolveAlertStrings() async {
  var language = AppLanguage.system;
  try {
    // 저장소가 응답하지 않아도 알림이 늦어지지 않게 시간을 제한한다
    language = await const AppLanguageStore().readFresh().timeout(
      const Duration(seconds: 1),
    );
  } on Object {
    // 읽지 못하면 기기 언어를 따른다
  }
  try {
    return AppStrings.forLocale(
      resolveAppLocale(language, PlatformDispatcher.instance.locales),
    );
  } on Object {
    return AppStrings.forLocale(fallbackAppLocale);
  }
}
