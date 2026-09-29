// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'EarLocAlert';

  @override
  String get settingsLanguageTitle => '言語';

  @override
  String get languageSheetHint => '選ぶとすぐに反映されます';

  @override
  String get languageFollowDevice => '端末の設定に合わせる';

  @override
  String languageFollowDeviceHint(String language) {
    return '現在: $language';
  }

  @override
  String get languageChanged => '言語を変更しました';

  @override
  String get languageUndo => '元に戻す';
}
