// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '이어폰위치알림';

  @override
  String get settingsLanguageTitle => '언어';

  @override
  String get languageSheetHint => '고르면 바로 적용됩니다';

  @override
  String get languageFollowDevice => '기기 설정 따르기';

  @override
  String languageFollowDeviceHint(String language) {
    return '지금은 $language';
  }

  @override
  String get languageChanged => '언어를 바꿨습니다';

  @override
  String get languageUndo => '되돌리기';
}
