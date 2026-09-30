import 'package:flutter/widgets.dart';

import 'app_language.dart';

/// 앱이 지원하는 언어 (이슈 #163). 이 목록 밖의 기기 언어는 영어로 보인다.
final supportedAppLocales = <Locale>[
  for (final language in AppLanguage.supported) Locale(language.storageValue),
];

const fallbackAppLocale = Locale('en');

/// 기기 언어 하나가 지원 대상인가 (번체 중국어 제외 규칙은 [AppLanguage.zh])
bool isSupportedDeviceLocale(Locale locale) =>
    AppLanguage.supported.any((language) => language.matchesDevice(locale));

/// 실제로 쓸 로케일을 정한다.
///
/// 1. 사용자가 설정에서 고른 언어가 있으면 그것이 기기 언어보다 우선한다
/// 2. `system` 이면 기기 언어 목록에서 처음 지원되는 것
/// 3. 하나도 없으면 영어
Locale resolveAppLocale(AppLanguage preference, List<Locale> deviceLocales) {
  final chosen = preference.locale;
  if (chosen != null) return chosen;
  for (final device in deviceLocales) {
    if (isSupportedDeviceLocale(device)) return Locale(device.languageCode);
  }
  return fallbackAppLocale;
}
