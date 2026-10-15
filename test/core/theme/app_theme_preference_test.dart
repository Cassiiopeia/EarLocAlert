import 'package:ear_loc_alert/core/theme/app_theme_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 화면 모드 설정 (이슈 #272)
void main() {
  test('모르는 값·null 은 기기 설정 따르기', () {
    expect(AppThemePreference.parse(null), AppThemePreference.system);
    expect(AppThemePreference.parse('purple'), AppThemePreference.system);
    expect(AppThemePreference.parse('light'), AppThemePreference.light);
    expect(AppThemePreference.parse('dark'), AppThemePreference.dark);
  });

  test('ThemeMode 로 옮긴다', () {
    expect(AppThemePreference.system.themeMode, ThemeMode.system);
    expect(AppThemePreference.light.themeMode, ThemeMode.light);
    expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
  });

  test('저장한 값을 다시 읽는다', () async {
    SharedPreferences.setMockInitialValues({});
    await const AppThemeStore().write(AppThemePreference.light);
    expect(await const AppThemeStore().read(), AppThemePreference.light);
  });

  test('저장된 값이 없으면 기기 설정 따르기', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await const AppThemeStore().read(), AppThemePreference.system);
  });
}
