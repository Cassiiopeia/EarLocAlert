import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

/// 앱 언어 설정의 저장소 (이슈 #163)
///
/// 도메인 데이터가 아니라 **단일 설정값**이라 SharedPreferences 를 쓴다
/// (docs/03-DOMAIN.md 저장소 경계). 그리고 네이티브(Kotlin)가 같은 값을
/// 읽어야 해서 Drift 가 아니다 — 알림은 앱이 죽어 있어도 네이티브가 만든다.
///
/// **키 이름은 앱과 네이티브의 계약이다.** Android 에서 이 플러그인은
/// `FlutterSharedPreferences` 파일에 `flutter.` 를 붙여 저장한다 —
/// 네이티브는 `flutter.app_language` 를 읽는다.
class AppLanguageStore {
  const AppLanguageStore();

  static const key = 'app_language';

  Future<AppLanguage> read() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLanguage.parse(prefs.getString(key));
  }

  /// **백그라운드 isolate 는 이것을 쓴다.** SharedPreferences 는 isolate 마다
  /// 캐시를 따로 가지므로, 읽기 전에 다시 불러오지 않으면 앱에서 방금 바꾼
  /// 언어를 모르고 옛 언어로 알림을 만든다 (`PendingAlertStore` 와 같은 이유).
  Future<AppLanguage> readFresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return AppLanguage.parse(prefs.getString(key));
  }

  Future<void> write(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, language.storageValue);
  }
}
