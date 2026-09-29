import 'package:flutter/widgets.dart';

import 'app_language.dart';

/// 앱이 지원하는 언어 (이슈 #163). 이 목록 밖의 기기 언어는 영어로 보인다.
const supportedAppLocales = <Locale>[
  Locale('ko'),
  Locale('en'),
  Locale('zh'),
  Locale('ja'),
];

const fallbackAppLocale = Locale('en');

/// 기기 언어 하나가 지원 대상인가.
///
/// **번체 중국어(대만, 홍콩, 마카오)는 지원하지 않는다.** 간체를 번체 기기에
/// 보이면 잘못된 자형이 오독으로 이어진다 — 영어로 보이게 둔다 (명세 4-A).
bool isSupportedDeviceLocale(Locale locale) {
  switch (locale.languageCode) {
    case 'ko':
    case 'en':
    case 'ja':
      return true;
    case 'zh':
      final traditionalScript = locale.scriptCode == 'Hant';
      const traditionalRegions = {'TW', 'HK', 'MO'};
      return !traditionalScript &&
          !traditionalRegions.contains(locale.countryCode);
    default:
      return false;
  }
}

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
