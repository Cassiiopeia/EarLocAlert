// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'EarLocAlert';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get languageSheetHint => 'Applies immediately';

  @override
  String get languageFollowDevice => 'Follow device settings';

  @override
  String languageFollowDeviceHint(String language) {
    return 'Currently $language';
  }

  @override
  String get languageChanged => 'Language changed';

  @override
  String get languageUndo => 'Undo';
}
