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
  zh('zh', nativeName: '中文'),
  ja('ja', nativeName: '日本語');

  const AppLanguage(this.storageValue, {this.nativeName});

  final String storageValue;

  /// **그 언어 자신의 표기.** 번역하지 않는다 — 읽을 수 없는 언어로 바뀐
  /// 사용자도 목록에서 자기 언어를 찾아 되돌릴 수 있어야 한다.
  final String? nativeName;

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
