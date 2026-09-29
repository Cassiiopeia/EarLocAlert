// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'EarLocAlert';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get languageSheetHint => '选择后立即生效';

  @override
  String get languageFollowDevice => '跟随设备设置';

  @override
  String languageFollowDeviceHint(String language) {
    return '当前：$language';
  }

  @override
  String get languageChanged => '语言已更改';

  @override
  String get languageUndo => '撤销';
}
