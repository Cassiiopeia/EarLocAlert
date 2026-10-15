import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자가 고른 화면 모드 (이슈 #272)
///
/// 기본은 기기 설정을 따른다. 언어 설정(`AppLanguage`)과 같은 구조다.
enum AppThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemePreference(this.storageValue);

  final String storageValue;

  /// 저장된 값을 읽는다. 모르는 값·빈 값은 기기 설정 따르기로 떨어진다 —
  /// 앱을 업데이트해 값 이름이 바뀌어도 화면이 깨지지 않게 한다
  static AppThemePreference parse(String? raw) => values.firstWhere(
    (value) => value.storageValue == raw,
    orElse: () => AppThemePreference.system,
  );

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}

/// 화면 모드 저장소 — SharedPreferences
class AppThemeStore {
  const AppThemeStore();

  static const key = 'app.theme_mode';

  Future<AppThemePreference> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppThemePreference.parse(prefs.getString(key));
    } on Object {
      // 읽기 실패는 기기 설정 따르기로 — 앱 시작을 막지 않는다
      return AppThemePreference.system;
    }
  }

  Future<void> write(AppThemePreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, preference.storageValue);
  }
}
