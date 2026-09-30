import 'package:flutter/widgets.dart';

/// 사용자가 고를 수 있는 앱 언어 (이슈 #163)
///
/// `system` 은 "기기 설정 따르기"다 — 기본값이다.
///
/// **저장 값(`storageValue`)은 앱과 네이티브의 계약이다.** 알림은 앱이 죽어
/// 있어도 Kotlin 이 만들기 때문에, 네이티브가 같은 값을 읽는다 (이슈 #164).
/// 이 이름을 바꾸면 양쪽이 어긋난다.
enum AppLanguage {
  system('system'),
  ko('ko', nativeName: '한국어'),
  en('en', nativeName: 'English'),

  /// **번체 중국어(대만, 홍콩, 마카오)는 지원하지 않는다.** 간체를 번체 기기에
  /// 보이면 잘못된 자형이 오독으로 이어진다 — 영어로 보이게 둔다 (명세 4-A).
  zh(
    'zh',
    nativeName: '中文',
    excludedScripts: {'Hant'},
    excludedRegions: {'TW', 'HK', 'MO'},
  ),
  ja('ja', nativeName: '日本語');

  const AppLanguage(
    this.storageValue, {
    this.nativeName,
    this.excludedScripts = const {},
    this.excludedRegions = const {},
  });

  final String storageValue;

  /// **그 언어 자신의 표기.** 번역하지 않는다 — 읽을 수 없는 언어로 바뀐
  /// 사용자도 목록에서 자기 언어를 찾아 되돌릴 수 있어야 한다.
  final String? nativeName;

  /// 같은 언어 코드여도 지원하지 않는 자형·지역 (기기 언어 판정에만 쓴다)
  final Set<String> excludedScripts;
  final Set<String> excludedRegions;

  /// 실제 번역이 있는 언어 — **지원 언어 목록의 단일 출처다.** 언어를 늘리려면
  /// 이 enum 에 한 줄을 더하면 지원 로케일과 기기 언어 판정이 따라온다.
  /// 나머지 자리는 `test/core/l10n/language_sync_test.dart` 가 지킨다.
  static final List<AppLanguage> supported = [
    for (final language in values)
      if (language != system) language,
  ];

  /// 기기 언어 하나가 이 언어로 보여도 되는가
  bool matchesDevice(Locale device) =>
      this != system &&
      device.languageCode == storageValue &&
      !excludedScripts.contains(device.scriptCode) &&
      !excludedRegions.contains(device.countryCode);

  /// 고른 언어의 로케일. `system` 이면 null (기기 언어를 따른다)
  Locale? get locale => this == system ? null : Locale(storageValue);

  /// 저장 값을 읽는다. 없거나 모르는 값이면 `system` 이다 — 앞으로 언어가
  /// 늘거나 줄어도 옛 값 때문에 앱이 깨지지 않는다.
  static AppLanguage parse(String? value) {
    for (final language in values) {
      if (language.storageValue == value) return language;
    }
    return system;
  }
}
