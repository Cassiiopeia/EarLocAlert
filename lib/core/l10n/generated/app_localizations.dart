import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In ko, this message translates to:
  /// **'이어폰위치알림'**
  String get appName;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settingsLanguageTitle;

  /// No description provided for @languageSheetHint.
  ///
  /// In ko, this message translates to:
  /// **'고르면 바로 적용됩니다'**
  String get languageSheetHint;

  /// No description provided for @languageFollowDevice.
  ///
  /// In ko, this message translates to:
  /// **'기기 설정 따르기'**
  String get languageFollowDevice;

  /// No description provided for @languageFollowDeviceHint.
  ///
  /// In ko, this message translates to:
  /// **'지금은 {language}'**
  String languageFollowDeviceHint(String language);

  /// No description provided for @languageChanged.
  ///
  /// In ko, this message translates to:
  /// **'언어를 바꿨습니다'**
  String get languageChanged;

  /// No description provided for @languageUndo.
  ///
  /// In ko, this message translates to:
  /// **'되돌리기'**
  String get languageUndo;

  /// No description provided for @permissionContinue.
  ///
  /// In ko, this message translates to:
  /// **'계속'**
  String get permissionContinue;

  /// No description provided for @permissionLocalOnlyFootnote.
  ///
  /// In ko, this message translates to:
  /// **'위치 정보는 기기에만 저장되며 어디에도 전송되지 않습니다.'**
  String get permissionLocalOnlyFootnote;

  /// No description provided for @permissionLocationTitle.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 필요합니다'**
  String get permissionLocationTitle;

  /// No description provided for @permissionLocationBody.
  ///
  /// In ko, this message translates to:
  /// **'알림을 걸어둘 장소를 지도에서 고르고, 지금 어디쯤인지 표시하기 위해 사용합니다.'**
  String get permissionLocationBody;

  /// No description provided for @permissionBackgroundTitle.
  ///
  /// In ko, this message translates to:
  /// **'항상 허용이 필요합니다'**
  String get permissionBackgroundTitle;

  /// No description provided for @permissionBackgroundBody.
  ///
  /// In ko, this message translates to:
  /// **'앱을 열어두지 않아도 도착과 출발을 알려드리려면 백그라운드에서 위치를 확인해야 합니다.\n\n이 권한이 없으면 화면을 계속 보고 있어야 해서, 알림 자체가 의미를 잃습니다.'**
  String get permissionBackgroundBody;

  /// No description provided for @permissionBackgroundActionAndroid.
  ///
  /// In ko, this message translates to:
  /// **'설정에서 항상 허용'**
  String get permissionBackgroundActionAndroid;

  /// No description provided for @permissionBackgroundFootnoteAndroid.
  ///
  /// In ko, this message translates to:
  /// **'설정 화면에서 위치 권한을 \"항상 허용\"으로 바꿔주세요.\n위치 정보는 기기에만 저장되며 어디에도 전송되지 않습니다.'**
  String get permissionBackgroundFootnoteAndroid;

  /// No description provided for @permissionNotificationTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림 권한이 필요합니다'**
  String get permissionNotificationTitle;

  /// No description provided for @permissionNotificationBody.
  ///
  /// In ko, this message translates to:
  /// **'도착하거나 떠날 때 알려드리기 위해 사용합니다.'**
  String get permissionNotificationBody;

  /// No description provided for @permissionReliabilityTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림을 놓치지 않으려면'**
  String get permissionReliabilityTitle;

  /// No description provided for @permissionReliabilityBody.
  ///
  /// In ko, this message translates to:
  /// **'휴대폰이 절전에 들어가거나 다른 앱을 보고 있으면, 도착 알림이 늦게 오거나 작은 알림으로만 지나갑니다.\n\n다음 세 가지를 켜면 화면을 덮는 알림이 해제할 때까지 계속됩니다.\n\n• 배터리 사용량 최적화 제외 — 절전 중에도 제때 알립니다\n• 다른 앱 위에 표시 — 영상을 보는 중에도 알림 화면이 뜹니다\n• 전체 화면 알림 — 화면이 꺼져 있어도 깨웁니다'**
  String get permissionReliabilityBody;

  /// No description provided for @permissionReliabilityAction.
  ///
  /// In ko, this message translates to:
  /// **'세 가지 모두 켜기'**
  String get permissionReliabilityAction;

  /// No description provided for @permissionReliabilityFootnote.
  ///
  /// In ko, this message translates to:
  /// **'설정 화면이 차례로 열립니다. 건너뛰면 알림 화면이 저절로 뜨지 않아, 진동을 끄려면 알림을 눌러 앱을 열어야 합니다.'**
  String get permissionReliabilityFootnote;

  /// No description provided for @permissionOpenSettingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정에서 직접 바꿔주세요'**
  String get permissionOpenSettingsTitle;

  /// No description provided for @permissionOpenSettingsBody.
  ///
  /// In ko, this message translates to:
  /// **'앱 안에서는 다시 물을 수 없는 권한이에요. 설정을 열어 아래처럼 바꿔주세요.'**
  String get permissionOpenSettingsBody;

  /// No description provided for @permissionOpenSettingsAction.
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get permissionOpenSettingsAction;

  /// No description provided for @permissionSettingsLocationRow.
  ///
  /// In ko, this message translates to:
  /// **'위치 → 앱을 사용하는 동안 또는 항상'**
  String get permissionSettingsLocationRow;

  /// No description provided for @permissionSettingsBackgroundRowIos.
  ///
  /// In ko, this message translates to:
  /// **'위치 → 항상'**
  String get permissionSettingsBackgroundRowIos;

  /// No description provided for @permissionSettingsBackgroundRowAndroid.
  ///
  /// In ko, this message translates to:
  /// **'위치 → 항상 허용'**
  String get permissionSettingsBackgroundRowAndroid;

  /// No description provided for @permissionSettingsNotificationRow.
  ///
  /// In ko, this message translates to:
  /// **'알림 → 알림 허용'**
  String get permissionSettingsNotificationRow;

  /// No description provided for @permissionSettingsReturnHintIos.
  ///
  /// In ko, this message translates to:
  /// **'바꾼 뒤 화면 왼쪽 위의 ◀ 앱 이름을 누르면 앱으로 돌아와요. 위치 권한을 바꾸면 앱이 다시 시작될 수 있어요.'**
  String get permissionSettingsReturnHintIos;

  /// No description provided for @permissionSettingsReturnHintAndroid.
  ///
  /// In ko, this message translates to:
  /// **'바꾼 뒤 뒤로 가기로 앱에 돌아오세요.'**
  String get permissionSettingsReturnHintAndroid;

  /// No description provided for @permissionDoneTitle.
  ///
  /// In ko, this message translates to:
  /// **'준비되었습니다'**
  String get permissionDoneTitle;

  /// No description provided for @permissionDoneBody.
  ///
  /// In ko, this message translates to:
  /// **'이제 장소를 등록하면 도착과 출발을 알려드립니다.'**
  String get permissionDoneBody;

  /// No description provided for @permissionDoneAction.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get permissionDoneAction;

  /// No description provided for @onboardingSkip.
  ///
  /// In ko, this message translates to:
  /// **'나중에 하기'**
  String get onboardingSkip;

  /// No description provided for @onboardingErrorTitle.
  ///
  /// In ko, this message translates to:
  /// **'권한 상태를 확인하지 못했습니다'**
  String get onboardingErrorTitle;

  /// No description provided for @onboardingErrorHint.
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요.'**
  String get onboardingErrorHint;

  /// No description provided for @onboardingRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get onboardingRetry;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAlert.
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get settingsSectionAlert;

  /// No description provided for @settingsVibrationTitle.
  ///
  /// In ko, this message translates to:
  /// **'진동 세기'**
  String get settingsVibrationTitle;

  /// No description provided for @settingsVibrationSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'이어폰이 없을 때는 진동만으로 알립니다'**
  String get settingsVibrationSubtitle;

  /// No description provided for @settingsVolumeTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림음 크기'**
  String get settingsVolumeTitle;

  /// No description provided for @settingsVolumeSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'이어폰으로 들릴 소리 크기'**
  String get settingsVolumeSubtitle;

  /// No description provided for @settingsSectionReach.
  ///
  /// In ko, this message translates to:
  /// **'알림 도달 권한'**
  String get settingsSectionReach;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In ko, this message translates to:
  /// **'일반'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionTroubleshoot.
  ///
  /// In ko, this message translates to:
  /// **'문제 해결'**
  String get settingsSectionTroubleshoot;

  /// No description provided for @settingsDiagnosticsTitle.
  ///
  /// In ko, this message translates to:
  /// **'동작 기록'**
  String get settingsDiagnosticsTitle;

  /// No description provided for @settingsDiagnosticsSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'알림이 언제 왜 울렸는지 기록을 보고 내보냅니다'**
  String get settingsDiagnosticsSubtitle;

  /// No description provided for @settingsPermissionGranted.
  ///
  /// In ko, this message translates to:
  /// **'허용됨'**
  String get settingsPermissionGranted;

  /// No description provided for @settingsPermNotifyTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림 표시'**
  String get settingsPermNotifyTitle;

  /// No description provided for @settingsPermNotifyDesc.
  ///
  /// In ko, this message translates to:
  /// **'없으면 도착해도 알림이 뜨지 않습니다'**
  String get settingsPermNotifyDesc;

  /// No description provided for @settingsPermBatteryTitle.
  ///
  /// In ko, this message translates to:
  /// **'배터리 최적화 제외'**
  String get settingsPermBatteryTitle;

  /// No description provided for @settingsPermBatteryDesc.
  ///
  /// In ko, this message translates to:
  /// **'없으면 절전 중 알림이 늦거나 오지 않습니다'**
  String get settingsPermBatteryDesc;

  /// No description provided for @settingsPermOverlayTitle.
  ///
  /// In ko, this message translates to:
  /// **'다른 앱 위에 표시'**
  String get settingsPermOverlayTitle;

  /// No description provided for @settingsPermOverlayDesc.
  ///
  /// In ko, this message translates to:
  /// **'없으면 앱 사용 중에 알림 화면이 뜨지 않습니다'**
  String get settingsPermOverlayDesc;

  /// No description provided for @settingsPermFullScreenTitle.
  ///
  /// In ko, this message translates to:
  /// **'전체 화면 알림'**
  String get settingsPermFullScreenTitle;

  /// No description provided for @settingsPermFullScreenDesc.
  ///
  /// In ko, this message translates to:
  /// **'없으면 화면이 꺼져 있을 때 알림 화면이 뜨지 않습니다'**
  String get settingsPermFullScreenDesc;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In ko, this message translates to:
  /// **'동작 기록'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로고침'**
  String get diagnosticsRefresh;

  /// No description provided for @diagnosticsClear.
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get diagnosticsClear;

  /// No description provided for @diagnosticsCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get diagnosticsCancel;

  /// No description provided for @diagnosticsExport.
  ///
  /// In ko, this message translates to:
  /// **'내보내기'**
  String get diagnosticsExport;

  /// No description provided for @diagnosticsExportSubject.
  ///
  /// In ko, this message translates to:
  /// **'이어폰위치알림 기록'**
  String get diagnosticsExportSubject;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In ko, this message translates to:
  /// **'클립보드에 복사했습니다'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsClearTitle.
  ///
  /// In ko, this message translates to:
  /// **'기록을 지울까요?'**
  String get diagnosticsClearTitle;

  /// No description provided for @diagnosticsClearBody.
  ///
  /// In ko, this message translates to:
  /// **'지운 기록은 되돌릴 수 없습니다.'**
  String get diagnosticsClearBody;

  /// No description provided for @diagnosticsHeader.
  ///
  /// In ko, this message translates to:
  /// **'{lineCount}건 · {size} / 최대 {maxSize}\n기기 안에만 저장되며 전송되지 않습니다. 가득 차면 오래된 것부터 지워집니다'**
  String diagnosticsHeader(int lineCount, String size, String maxSize);

  /// No description provided for @diagnosticsReadFailed.
  ///
  /// In ko, this message translates to:
  /// **'기록을 읽지 못했습니다.'**
  String get diagnosticsReadFailed;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 기록이 없습니다.\n앱을 다시 켜거나 감시가 시작되면 쌓입니다.'**
  String get diagnosticsEmpty;

  /// No description provided for @diagnosticsCopyAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 복사'**
  String get diagnosticsCopyAll;

  /// No description provided for @diagnosticsAppState.
  ///
  /// In ko, this message translates to:
  /// **'앱 상태'**
  String get diagnosticsAppState;

  /// No description provided for @diagnosticsAppStateHint.
  ///
  /// In ko, this message translates to:
  /// **'권한·장소·설정·기기 상태입니다. 내보내기에 함께 담깁니다'**
  String get diagnosticsAppStateHint;

  /// No description provided for @diagnosticsSearchHint.
  ///
  /// In ko, this message translates to:
  /// **'태그·장소·내용 검색'**
  String get diagnosticsSearchHint;

  /// No description provided for @diagnosticsProblemsOnly.
  ///
  /// In ko, this message translates to:
  /// **'문제만 {count}'**
  String diagnosticsProblemsOnly(int count);

  /// No description provided for @diagnosticsAllSources.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get diagnosticsAllSources;

  /// No description provided for @diagnosticsSourceApp.
  ///
  /// In ko, this message translates to:
  /// **'앱'**
  String get diagnosticsSourceApp;

  /// No description provided for @diagnosticsSourceBackground.
  ///
  /// In ko, this message translates to:
  /// **'백그라운드'**
  String get diagnosticsSourceBackground;

  /// No description provided for @diagnosticsSourceNative.
  ///
  /// In ko, this message translates to:
  /// **'네이티브'**
  String get diagnosticsSourceNative;

  /// No description provided for @diagnosticsSourceIos.
  ///
  /// In ko, this message translates to:
  /// **'iOS'**
  String get diagnosticsSourceIos;

  /// No description provided for @diagnosticsShownCount.
  ///
  /// In ko, this message translates to:
  /// **'{shown}건 표시 중'**
  String diagnosticsShownCount(int shown);

  /// No description provided for @diagnosticsPeriod.
  ///
  /// In ko, this message translates to:
  /// **'기간 {from} ~ {to}'**
  String diagnosticsPeriod(String from, String to);

  /// No description provided for @diagnosticsNoMatch.
  ///
  /// In ko, this message translates to:
  /// **'조건에 맞는 기록이 없습니다.'**
  String get diagnosticsNoMatch;

  /// No description provided for @routeDeletedSound.
  ///
  /// In ko, this message translates to:
  /// **'삭제된 음원 (기본음으로 알림)'**
  String get routeDeletedSound;

  /// No description provided for @notificationChannelName.
  ///
  /// In ko, this message translates to:
  /// **'도착·출발 알림'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In ko, this message translates to:
  /// **'등록한 장소에 도착하거나 떠날 때 알립니다'**
  String get notificationChannelDescription;

  /// No description provided for @notificationArrived.
  ///
  /// In ko, this message translates to:
  /// **'도착했습니다'**
  String get notificationArrived;

  /// No description provided for @notificationLeft.
  ///
  /// In ko, this message translates to:
  /// **'떠났습니다'**
  String get notificationLeft;

  /// No description provided for @alertScreenLeft.
  ///
  /// In ko, this message translates to:
  /// **'떠났습니다'**
  String get alertScreenLeft;

  /// No description provided for @alertScreenArrived.
  ///
  /// In ko, this message translates to:
  /// **'도착했습니다'**
  String get alertScreenArrived;

  /// No description provided for @alertScreenTimeAm.
  ///
  /// In ko, this message translates to:
  /// **'오전 {hour}:{minute}'**
  String alertScreenTimeAm(String hour, String minute);

  /// No description provided for @alertScreenTimePm.
  ///
  /// In ko, this message translates to:
  /// **'오후 {hour}:{minute}'**
  String alertScreenTimePm(String hour, String minute);

  /// No description provided for @alertScreenRouteHeadphones.
  ///
  /// In ko, this message translates to:
  /// **'이어폰으로 알림 중'**
  String get alertScreenRouteHeadphones;

  /// No description provided for @alertScreenRouteSoundFailed.
  ///
  /// In ko, this message translates to:
  /// **'소리를 재생하지 못해 진동으로 알림 중'**
  String get alertScreenRouteSoundFailed;

  /// No description provided for @alertScreenRouteVibrationOnly.
  ///
  /// In ko, this message translates to:
  /// **'진동으로만 알림 중'**
  String get alertScreenRouteVibrationOnly;

  /// No description provided for @alertScreenDismiss.
  ///
  /// In ko, this message translates to:
  /// **'알림 끄기'**
  String get alertScreenDismiss;

  /// 잠금 화면 알람(iOS 26 AlarmKit)의 보조 버튼. 누르면 앱의 알림 화면이 열린다 (이슈 #241)
  ///
  /// In ko, this message translates to:
  /// **'앱 열기'**
  String get alertAlarmOpenApp;

  /// No description provided for @alertScreenRadius.
  ///
  /// In ko, this message translates to:
  /// **'반경 {meters}m'**
  String alertScreenRadius(int meters);

  /// No description provided for @alertNotificationChannelName.
  ///
  /// In ko, this message translates to:
  /// **'알림 진행 중'**
  String get alertNotificationChannelName;

  /// No description provided for @alertNotificationChannelDescription.
  ///
  /// In ko, this message translates to:
  /// **'알림 화면을 벗어났을 때 다시 돌아오는 알림입니다'**
  String get alertNotificationChannelDescription;

  /// No description provided for @alertDismissedTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림을 껐습니다'**
  String get alertDismissedTitle;

  /// No description provided for @volumeTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림음 크기'**
  String get volumeTitle;

  /// No description provided for @volumeDescription.
  ///
  /// In ko, this message translates to:
  /// **'알림이 울릴 때 시스템 볼륨이 이 수준보다 낮으면 여기까지 올렸다가, 끄면 원래대로 되돌립니다.'**
  String get volumeDescription;

  /// No description provided for @volumePreviewStop.
  ///
  /// In ko, this message translates to:
  /// **'미리듣기 멈추기'**
  String get volumePreviewStop;

  /// No description provided for @volumePreviewNoHeadphones.
  ///
  /// In ko, this message translates to:
  /// **'이어폰이 연결되어 있지 않아 미리듣기를 할 수 없습니다.'**
  String get volumePreviewNoHeadphones;

  /// No description provided for @volumePreviewFailed.
  ///
  /// In ko, this message translates to:
  /// **'재생에 실패했습니다.'**
  String get volumePreviewFailed;

  /// No description provided for @vibrationTitle.
  ///
  /// In ko, this message translates to:
  /// **'진동 세기'**
  String get vibrationTitle;

  /// No description provided for @vibrationDescription.
  ///
  /// In ko, this message translates to:
  /// **'이어폰이 연결되지 않았을 때는 진동만으로 알립니다. 고르면 그 세기로 한 번 울려 확인할 수 있습니다.'**
  String get vibrationDescription;

  /// No description provided for @vibrationWeak.
  ///
  /// In ko, this message translates to:
  /// **'약하게'**
  String get vibrationWeak;

  /// No description provided for @vibrationNormal.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get vibrationNormal;

  /// No description provided for @vibrationStrong.
  ///
  /// In ko, this message translates to:
  /// **'강하게'**
  String get vibrationStrong;

  /// No description provided for @vibrationWeakHint.
  ///
  /// In ko, this message translates to:
  /// **'조용한 곳에서 주변에 들리지 않게'**
  String get vibrationWeakHint;

  /// No description provided for @vibrationNormalHint.
  ///
  /// In ko, this message translates to:
  /// **'기본값'**
  String get vibrationNormalHint;

  /// No description provided for @vibrationStrongHint.
  ///
  /// In ko, this message translates to:
  /// **'주머니나 가방 속에서도 느껴지게'**
  String get vibrationStrongHint;

  /// No description provided for @soundPreview.
  ///
  /// In ko, this message translates to:
  /// **'미리듣기'**
  String get soundPreview;

  /// No description provided for @soundCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get soundCancel;

  /// No description provided for @soundDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get soundDelete;

  /// No description provided for @soundDone.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get soundDone;

  /// No description provided for @soundPickerTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림음'**
  String get soundPickerTitle;

  /// No description provided for @soundPickerPresetHeader.
  ///
  /// In ko, this message translates to:
  /// **'기본 알림음'**
  String get soundPickerPresetHeader;

  /// No description provided for @soundPickerCustomHeader.
  ///
  /// In ko, this message translates to:
  /// **'내 음원  {count}/{max}'**
  String soundPickerCustomHeader(int count, int max);

  /// No description provided for @soundPickerCustomEmpty.
  ///
  /// In ko, this message translates to:
  /// **'기기에 있는 음원 파일을 등록해 쓸 수 있습니다.'**
  String get soundPickerCustomEmpty;

  /// No description provided for @soundPickerAdd.
  ///
  /// In ko, this message translates to:
  /// **'음원 추가'**
  String get soundPickerAdd;

  /// No description provided for @soundPickerChecking.
  ///
  /// In ko, this message translates to:
  /// **'확인 중…'**
  String get soundPickerChecking;

  /// No description provided for @soundPickerHeadphoneNotice.
  ///
  /// In ko, this message translates to:
  /// **'이어폰을 연결하면 들어볼 수 있습니다. 알림음은 이어폰이 연결됐을 때만 재생됩니다.'**
  String get soundPickerHeadphoneNotice;

  /// No description provided for @soundPreviewFailed.
  ///
  /// In ko, this message translates to:
  /// **'재생할 수 없는 음원입니다'**
  String get soundPreviewFailed;

  /// No description provided for @soundSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'음원을 저장하지 못했습니다. 잠시 후 다시 시도해주세요.'**
  String get soundSaveFailed;

  /// No description provided for @soundDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'음원을 삭제할까요?'**
  String get soundDeleteTitle;

  /// No description provided for @soundDeleteBody.
  ///
  /// In ko, this message translates to:
  /// **'{name}\n\n이 음원을 쓰던 장소는 기본음으로 알립니다.'**
  String soundDeleteBody(String name);

  /// No description provided for @soundDurationMinutesSeconds.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 {seconds}초'**
  String soundDurationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @soundImportLimitReached.
  ///
  /// In ko, this message translates to:
  /// **'음원은 최대 {max}개까지 등록할 수 있습니다. 쓰지 않는 음원을 지우고 다시 시도해주세요.'**
  String soundImportLimitReached(int max);

  /// No description provided for @soundImportNoExtension.
  ///
  /// In ko, this message translates to:
  /// **'확장자가 없는 파일입니다. {allowed} 형식만 쓸 수 있습니다.'**
  String soundImportNoExtension(String allowed);

  /// No description provided for @soundImportUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'{extension} 형식은 쓸 수 없습니다. {allowed} 만 가능합니다.'**
  String soundImportUnsupported(String extension, String allowed);

  /// No description provided for @soundImportTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'파일이 너무 큽니다 ({size} / 최대 {max}).'**
  String soundImportTooLarge(String size, String max);

  /// No description provided for @soundImportTooLong.
  ///
  /// In ko, this message translates to:
  /// **'너무 깁니다 ({duration} / 최대 {max}). 알림음은 반복 재생되므로 짧아도 됩니다.'**
  String soundImportTooLong(String duration, String max);

  /// No description provided for @soundImportNotPlayable.
  ///
  /// In ko, this message translates to:
  /// **'재생할 수 없는 파일입니다. 다른 파일을 골라주세요.'**
  String get soundImportNotPlayable;

  /// No description provided for @soundPresetDefault.
  ///
  /// In ko, this message translates to:
  /// **'기본음'**
  String get soundPresetDefault;

  /// No description provided for @soundPresetBell.
  ///
  /// In ko, this message translates to:
  /// **'종소리'**
  String get soundPresetBell;

  /// No description provided for @soundPresetElectronic.
  ///
  /// In ko, this message translates to:
  /// **'전자음'**
  String get soundPresetElectronic;

  /// No description provided for @soundPresetSiren.
  ///
  /// In ko, this message translates to:
  /// **'사이렌'**
  String get soundPresetSiren;

  /// No description provided for @soundPresetChime.
  ///
  /// In ko, this message translates to:
  /// **'차임'**
  String get soundPresetChime;

  /// No description provided for @placeSearchUnnamed.
  ///
  /// In ko, this message translates to:
  /// **'이름 없는 장소'**
  String get placeSearchUnnamed;

  /// No description provided for @placePickerTitle.
  ///
  /// In ko, this message translates to:
  /// **'지도에서 선택'**
  String get placePickerTitle;

  /// No description provided for @placeMyLocation.
  ///
  /// In ko, this message translates to:
  /// **'내 위치'**
  String get placeMyLocation;

  /// No description provided for @placeSearchHint.
  ///
  /// In ko, this message translates to:
  /// **'장소·주소 검색'**
  String get placeSearchHint;

  /// No description provided for @placeSearchUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'검색을 사용할 수 없습니다 — 지도를 움직여 위치를 맞춰주세요'**
  String get placeSearchUnavailable;

  /// No description provided for @placePickerPinHint.
  ///
  /// In ko, this message translates to:
  /// **'지도를 움직여 핀을 맞추세요'**
  String get placePickerPinHint;

  /// No description provided for @placePickerConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 위치로 선택'**
  String get placePickerConfirm;

  /// No description provided for @placeDirectionEnter.
  ///
  /// In ko, this message translates to:
  /// **'도착 알림'**
  String get placeDirectionEnter;

  /// No description provided for @placeDirectionExit.
  ///
  /// In ko, this message translates to:
  /// **'출발 알림'**
  String get placeDirectionExit;

  /// No description provided for @placeDirectionBoth.
  ///
  /// In ko, this message translates to:
  /// **'도착·출발'**
  String get placeDirectionBoth;

  /// No description provided for @placeRadiusInfo.
  ///
  /// In ko, this message translates to:
  /// **'{direction} · 반경 {meters}m'**
  String placeRadiusInfo(String direction, int meters);

  /// No description provided for @placeDeleted.
  ///
  /// In ko, this message translates to:
  /// **'\'{name}\' 삭제됨'**
  String placeDeleted(String name);

  /// No description provided for @placeUndo.
  ///
  /// In ko, this message translates to:
  /// **'되돌리기'**
  String get placeUndo;

  /// No description provided for @placeSwipeDeleteLabel.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get placeSwipeDeleteLabel;

  /// No description provided for @placeFormDelete.
  ///
  /// In ko, this message translates to:
  /// **'이 장소 삭제'**
  String get placeFormDelete;

  /// No description provided for @placeFormDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 장소를 삭제할까요?'**
  String get placeFormDeleteTitle;

  /// No description provided for @placeFormDeleteBody.
  ///
  /// In ko, this message translates to:
  /// **'\'{name}\' 장소가 목록에서 사라집니다. 삭제한 직후에는 되돌릴 수 있습니다.'**
  String placeFormDeleteBody(String name);

  /// No description provided for @placeDeleteCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get placeDeleteCancel;

  /// No description provided for @placeFormLeaveTitle.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 않고 나갈까요?'**
  String get placeFormLeaveTitle;

  /// No description provided for @placeFormLeaveBody.
  ///
  /// In ko, this message translates to:
  /// **'지금까지 바꾼 내용은 사라집니다.'**
  String get placeFormLeaveBody;

  /// No description provided for @placeFormKeepEditing.
  ///
  /// In ko, this message translates to:
  /// **'계속 편집'**
  String get placeFormKeepEditing;

  /// No description provided for @placeFormLeave.
  ///
  /// In ko, this message translates to:
  /// **'나가기'**
  String get placeFormLeave;

  /// No description provided for @placeFormTitleNew.
  ///
  /// In ko, this message translates to:
  /// **'장소 등록'**
  String get placeFormTitleNew;

  /// No description provided for @placeFormTitleEdit.
  ///
  /// In ko, this message translates to:
  /// **'장소 편집'**
  String get placeFormTitleEdit;

  /// No description provided for @placeFormNameLabel.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get placeFormNameLabel;

  /// No description provided for @placeFormNameHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 내릴 정류장, 약속 장소'**
  String get placeFormNameHint;

  /// No description provided for @placeFormLocationLabel.
  ///
  /// In ko, this message translates to:
  /// **'위치'**
  String get placeFormLocationLabel;

  /// No description provided for @placeFormPickOnMap.
  ///
  /// In ko, this message translates to:
  /// **'지도에서 선택'**
  String get placeFormPickOnMap;

  /// No description provided for @placeFormRepickOnMap.
  ///
  /// In ko, this message translates to:
  /// **'지도에서 다시 선택'**
  String get placeFormRepickOnMap;

  /// No description provided for @placeFormNoLocation.
  ///
  /// In ko, this message translates to:
  /// **'아직 위치를 고르지 않았습니다'**
  String get placeFormNoLocation;

  /// No description provided for @placeFormCoordinates.
  ///
  /// In ko, this message translates to:
  /// **'좌표  {value}'**
  String placeFormCoordinates(String value);

  /// No description provided for @placeFormCoordinatesManual.
  ///
  /// In ko, this message translates to:
  /// **'좌표 직접 입력'**
  String get placeFormCoordinatesManual;

  /// No description provided for @placeFormLatitude.
  ///
  /// In ko, this message translates to:
  /// **'위도'**
  String get placeFormLatitude;

  /// No description provided for @placeFormLongitude.
  ///
  /// In ko, this message translates to:
  /// **'경도'**
  String get placeFormLongitude;

  /// No description provided for @placeFormRadiusLabel.
  ///
  /// In ko, this message translates to:
  /// **'알림 반경'**
  String get placeFormRadiusLabel;

  /// No description provided for @placeFormRadiusValue.
  ///
  /// In ko, this message translates to:
  /// **'{meters}m'**
  String placeFormRadiusValue(int meters);

  /// No description provided for @placeFormTimingLabel.
  ///
  /// In ko, this message translates to:
  /// **'알림 시점'**
  String get placeFormTimingLabel;

  /// No description provided for @placeFormTimingEnter.
  ///
  /// In ko, this message translates to:
  /// **'도착'**
  String get placeFormTimingEnter;

  /// No description provided for @placeFormTimingExit.
  ///
  /// In ko, this message translates to:
  /// **'출발'**
  String get placeFormTimingExit;

  /// No description provided for @placeFormTimingBoth.
  ///
  /// In ko, this message translates to:
  /// **'둘 다'**
  String get placeFormTimingBoth;

  /// No description provided for @placeFormSoundTitle.
  ///
  /// In ko, this message translates to:
  /// **'이어폰 소리 알림'**
  String get placeFormSoundTitle;

  /// No description provided for @placeFormSoundDescription.
  ///
  /// In ko, this message translates to:
  /// **'이어폰(줄·블루투스)이 연결된 경우에만 소리가 납니다.\n스피커로는 절대 소리가 나지 않습니다.'**
  String get placeFormSoundDescription;

  /// No description provided for @placeFormSoundLabel.
  ///
  /// In ko, this message translates to:
  /// **'알림음'**
  String get placeFormSoundLabel;

  /// No description provided for @placeFormCustomSound.
  ///
  /// In ko, this message translates to:
  /// **'내 음원'**
  String get placeFormCustomSound;

  /// No description provided for @placeFormSubmitNew.
  ///
  /// In ko, this message translates to:
  /// **'등록'**
  String get placeFormSubmitNew;

  /// No description provided for @placeFormSubmitSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get placeFormSubmitSave;

  /// No description provided for @placeErrorEmptyName.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해주세요'**
  String get placeErrorEmptyName;

  /// No description provided for @placeErrorRadius.
  ///
  /// In ko, this message translates to:
  /// **'반경은 {min}m ~ {max}m 사이여야 합니다'**
  String placeErrorRadius(int min, int max);

  /// No description provided for @placeErrorCoordinates.
  ///
  /// In ko, this message translates to:
  /// **'위치 좌표가 올바르지 않습니다'**
  String get placeErrorCoordinates;

  /// No description provided for @placeErrorLimit.
  ///
  /// In ko, this message translates to:
  /// **'장소는 최대 {max}개까지 등록할 수 있습니다'**
  String placeErrorLimit(int max);

  /// No description provided for @placeErrorEmptyWindow.
  ///
  /// In ko, this message translates to:
  /// **'시간대의 시작과 종료가 같습니다. 하루 종일 알리려면 시간대를 지우세요'**
  String get placeErrorEmptyWindow;

  /// No description provided for @placeErrorNoDays.
  ///
  /// In ko, this message translates to:
  /// **'시간대에 요일을 하나 이상 골라주세요'**
  String get placeErrorNoDays;

  /// No description provided for @placeEmptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'첫 장소를 등록해주세요'**
  String get placeEmptyTitle;

  /// No description provided for @placeEmptyAction.
  ///
  /// In ko, this message translates to:
  /// **'장소 등록'**
  String get placeEmptyAction;

  /// No description provided for @placeHomeLocationUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치를 확인할 수 없습니다. 위치 권한을 확인해주세요'**
  String get placeHomeLocationUnavailable;

  /// No description provided for @placeLocationSlow.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치를 찾는 중 시간이 걸리고 있어요. 잠시 후 다시 눌러주세요'**
  String get placeLocationSlow;

  /// No description provided for @placeHomeStatusWatching.
  ///
  /// In ko, this message translates to:
  /// **'감시 중'**
  String get placeHomeStatusWatching;

  /// No description provided for @placeHomeStatusOff.
  ///
  /// In ko, this message translates to:
  /// **'감시 꺼짐'**
  String get placeHomeStatusOff;

  /// No description provided for @placeHomeStatusChecking.
  ///
  /// In ko, this message translates to:
  /// **'확인 중'**
  String get placeHomeStatusChecking;

  /// No description provided for @placeHomeStatusIdle.
  ///
  /// In ko, this message translates to:
  /// **'감시 대기'**
  String get placeHomeStatusIdle;

  /// No description provided for @placeHomeAudioHeadphones.
  ///
  /// In ko, this message translates to:
  /// **'이어폰'**
  String get placeHomeAudioHeadphones;

  /// No description provided for @placeHomeAudioVibrationOnly.
  ///
  /// In ko, this message translates to:
  /// **'진동만'**
  String get placeHomeAudioVibrationOnly;

  /// No description provided for @placeHomeWeakTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림을 놓칠 수 있습니다'**
  String get placeHomeWeakTitle;

  /// No description provided for @placeHomeWeakPowerSaving.
  ///
  /// In ko, this message translates to:
  /// **'절전 중이거나 다른 앱을 쓰는 동안 알림이 약해집니다'**
  String get placeHomeWeakPowerSaving;

  /// No description provided for @placeHomeWeakMissing.
  ///
  /// In ko, this message translates to:
  /// **'{items} 꺼짐 — 눌러서 켜기'**
  String placeHomeWeakMissing(String items);

  /// No description provided for @placeHomeAddPlace.
  ///
  /// In ko, this message translates to:
  /// **'장소 추가'**
  String get placeHomeAddPlace;

  /// No description provided for @placeHomeLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'장소를 불러오지 못했습니다'**
  String get placeHomeLoadFailed;

  /// No description provided for @placeHomeSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get placeHomeSettings;

  /// No description provided for @scheduleTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림 시간대'**
  String get scheduleTitle;

  /// No description provided for @scheduleAlways.
  ///
  /// In ko, this message translates to:
  /// **'항상 알림'**
  String get scheduleAlways;

  /// No description provided for @scheduleAlwaysHint.
  ///
  /// In ko, this message translates to:
  /// **'항상 알림 — 시간대를 더하면 그 시간에만 울립니다'**
  String get scheduleAlwaysHint;

  /// No description provided for @scheduleAdd.
  ///
  /// In ko, this message translates to:
  /// **'시간대 추가'**
  String get scheduleAdd;

  /// No description provided for @scheduleRemove.
  ///
  /// In ko, this message translates to:
  /// **'이 시간대 삭제'**
  String get scheduleRemove;

  /// No description provided for @scheduleSheetAddTitle.
  ///
  /// In ko, this message translates to:
  /// **'시간대 추가'**
  String get scheduleSheetAddTitle;

  /// No description provided for @scheduleSheetEditTitle.
  ///
  /// In ko, this message translates to:
  /// **'시간대 편집'**
  String get scheduleSheetEditTitle;

  /// No description provided for @scheduleDaysLabel.
  ///
  /// In ko, this message translates to:
  /// **'요일'**
  String get scheduleDaysLabel;

  /// No description provided for @scheduleEveryday.
  ///
  /// In ko, this message translates to:
  /// **'매일'**
  String get scheduleEveryday;

  /// No description provided for @scheduleWeekdays.
  ///
  /// In ko, this message translates to:
  /// **'평일'**
  String get scheduleWeekdays;

  /// No description provided for @scheduleWeekends.
  ///
  /// In ko, this message translates to:
  /// **'주말'**
  String get scheduleWeekends;

  /// No description provided for @scheduleDayMon.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get scheduleDayMon;

  /// No description provided for @scheduleDayTue.
  ///
  /// In ko, this message translates to:
  /// **'화'**
  String get scheduleDayTue;

  /// No description provided for @scheduleDayWed.
  ///
  /// In ko, this message translates to:
  /// **'수'**
  String get scheduleDayWed;

  /// No description provided for @scheduleDayThu.
  ///
  /// In ko, this message translates to:
  /// **'목'**
  String get scheduleDayThu;

  /// No description provided for @scheduleDayFri.
  ///
  /// In ko, this message translates to:
  /// **'금'**
  String get scheduleDayFri;

  /// No description provided for @scheduleDaySat.
  ///
  /// In ko, this message translates to:
  /// **'토'**
  String get scheduleDaySat;

  /// No description provided for @scheduleDaySun.
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get scheduleDaySun;

  /// No description provided for @scheduleStart.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get scheduleStart;

  /// No description provided for @scheduleEnd.
  ///
  /// In ko, this message translates to:
  /// **'종료'**
  String get scheduleEnd;

  /// No description provided for @scheduleCrossesMidnight.
  ///
  /// In ko, this message translates to:
  /// **'종료가 시작보다 이르므로 자정을 넘긴 것으로 봅니다 — {window}'**
  String scheduleCrossesMidnight(String window);

  /// No description provided for @scheduleSameStartEnd.
  ///
  /// In ko, this message translates to:
  /// **'시작과 종료가 같습니다. 하루 종일 알리려면 시간대를 만들지 않으면 됩니다.'**
  String get scheduleSameStartEnd;

  /// No description provided for @scheduleSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get scheduleSave;

  /// No description provided for @scheduleAddButton.
  ///
  /// In ko, this message translates to:
  /// **'추가'**
  String get scheduleAddButton;

  /// No description provided for @settingsWatchTitle.
  ///
  /// In ko, this message translates to:
  /// **'워치로 알림 받기'**
  String get settingsWatchTitle;

  /// No description provided for @settingsWatchSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'스마트워치에서도 도착 알림을 받는 방법'**
  String get settingsWatchSubtitle;

  /// No description provided for @watchGuideIntro.
  ///
  /// In ko, this message translates to:
  /// **'스마트워치를 차고 있다면 워치에서도 알림을 받을 수 있어요. 워치 쪽 설정을 한 번만 켜 주세요.'**
  String get watchGuideIntro;

  /// No description provided for @watchGuideAndroidStep1.
  ///
  /// In ko, this message translates to:
  /// **'폰에서 Galaxy Wearable 같은 워치 앱을 엽니다'**
  String get watchGuideAndroidStep1;

  /// No description provided for @watchGuideAndroidStep2.
  ///
  /// In ko, this message translates to:
  /// **'워치 설정 → 알림 → 앱 알림으로 들어갑니다'**
  String get watchGuideAndroidStep2;

  /// No description provided for @watchGuideAndroidStep3.
  ///
  /// In ko, this message translates to:
  /// **'목록에서 \"{appName}\"을 켭니다'**
  String watchGuideAndroidStep3(String appName);

  /// No description provided for @watchGuideIosStep1.
  ///
  /// In ko, this message translates to:
  /// **'iPhone 에서 Watch 앱을 엽니다'**
  String get watchGuideIosStep1;

  /// No description provided for @watchGuideIosStep2.
  ///
  /// In ko, this message translates to:
  /// **'알림으로 들어갑니다'**
  String get watchGuideIosStep2;

  /// No description provided for @watchGuideIosStep3.
  ///
  /// In ko, this message translates to:
  /// **'\"{appName}\"이 보이면 켭니다. iPhone 이 잠겨 있을 때 워치로 알림이 갑니다'**
  String watchGuideIosStep3(String appName);

  /// No description provided for @watchGuideNote.
  ///
  /// In ko, this message translates to:
  /// **'워치가 울리는 방식은 워치 설정에 따라 다를 수 있어요.'**
  String get watchGuideNote;

  /// No description provided for @watchGuideConfirm.
  ///
  /// In ko, this message translates to:
  /// **'알겠어요'**
  String get watchGuideConfirm;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In ko, this message translates to:
  /// **'화면 모드'**
  String get settingsThemeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In ko, this message translates to:
  /// **'기기 설정 따르기'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeDark;

  /// No description provided for @themeSheetHint.
  ///
  /// In ko, this message translates to:
  /// **'알림이 울리는 화면은 눈부시지 않게 항상 어둡게 보여요.'**
  String get themeSheetHint;

  /// No description provided for @themeChanged.
  ///
  /// In ko, this message translates to:
  /// **'화면 모드를 바꿨어요'**
  String get themeChanged;

  /// No description provided for @themeUndo.
  ///
  /// In ko, this message translates to:
  /// **'되돌리기'**
  String get themeUndo;

  /// No description provided for @placeFormSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 못했습니다. 잠시 후 다시 시도해주세요.'**
  String get placeFormSaveFailed;

  /// No description provided for @scheduleCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get scheduleCancel;

  /// No description provided for @scheduleWindow.
  ///
  /// In ko, this message translates to:
  /// **'{days} {start} ~ {end}'**
  String scheduleWindow(String days, String start, String end);

  /// No description provided for @scheduleWindowNextDay.
  ///
  /// In ko, this message translates to:
  /// **'{days} {start} ~ {end} (익일)'**
  String scheduleWindowNextDay(String days, String start, String end);

  /// No description provided for @scheduleTimeRange.
  ///
  /// In ko, this message translates to:
  /// **'{start} ~ {end}'**
  String scheduleTimeRange(String start, String end);

  /// No description provided for @scheduleTimeRangeNextDay.
  ///
  /// In ko, this message translates to:
  /// **'{start} ~ {end} (익일)'**
  String scheduleTimeRangeNextDay(String start, String end);

  /// No description provided for @scheduleMore.
  ///
  /// In ko, this message translates to:
  /// **'{first} 외 {count}개'**
  String scheduleMore(String first, int count);

  /// No description provided for @appUpdateReady.
  ///
  /// In ko, this message translates to:
  /// **'새 버전을 받았어요'**
  String get appUpdateReady;

  /// No description provided for @appUpdateRestart.
  ///
  /// In ko, this message translates to:
  /// **'다시 시작'**
  String get appUpdateRestart;

  /// No description provided for @settingsVersionTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 버전'**
  String get settingsVersionTitle;

  /// No description provided for @settingsVersionCheck.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 확인'**
  String get settingsVersionCheck;

  /// No description provided for @appUpdateNone.
  ///
  /// In ko, this message translates to:
  /// **'지금 받을 수 있는 업데이트가 없어요'**
  String get appUpdateNone;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get settingsSectionAbout;

  /// No description provided for @settingsTermsTitle.
  ///
  /// In ko, this message translates to:
  /// **'이용약관'**
  String get settingsTermsTitle;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsLicensesTitle.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get settingsLicensesTitle;

  /// No description provided for @settingsAdPrivacyTitle.
  ///
  /// In ko, this message translates to:
  /// **'광고 개인정보 설정'**
  String get settingsAdPrivacyTitle;

  /// No description provided for @settingsAdPrivacySubtitle.
  ///
  /// In ko, this message translates to:
  /// **'광고 동의 선택을 다시 확인하거나 바꿉니다'**
  String get settingsAdPrivacySubtitle;

  /// No description provided for @settingsOpenLinkFailed.
  ///
  /// In ko, this message translates to:
  /// **'링크를 열 수 없어요. 브라우저가 설치되어 있는지 확인해 주세요'**
  String get settingsOpenLinkFailed;

  /// No description provided for @settingsLockAlarmTitle.
  ///
  /// In ko, this message translates to:
  /// **'잠금화면 알람'**
  String get settingsLockAlarmTitle;

  /// No description provided for @settingsLockAlarmOn.
  ///
  /// In ko, this message translates to:
  /// **'화면이 꺼져 있으면 잠금 화면 전체에 알람을 띄워요'**
  String get settingsLockAlarmOn;

  /// No description provided for @settingsLockAlarmNotDetermined.
  ///
  /// In ko, this message translates to:
  /// **'허용하면 화면이 꺼져 있을 때 잠금 화면 전체에 알람을 띄워요'**
  String get settingsLockAlarmNotDetermined;

  /// No description provided for @settingsLockAlarmDenied.
  ///
  /// In ko, this message translates to:
  /// **'꺼져 있어요. 설정에서 알람을 허용하면 잠금 화면 전체에 알람을 띄워요'**
  String get settingsLockAlarmDenied;

  /// No description provided for @settingsLockAlarmNeedsNewerOs.
  ///
  /// In ko, this message translates to:
  /// **'화면 전체를 덮는 알람은 iOS 26 이상에서 쓸 수 있어요. 지금은 알림과 진동으로 알려 드려요.'**
  String get settingsLockAlarmNeedsNewerOs;

  /// No description provided for @settingsLockAlarmAllow.
  ///
  /// In ko, this message translates to:
  /// **'허용'**
  String get settingsLockAlarmAllow;

  /// No description provided for @settingsLockAlarmOpenSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get settingsLockAlarmOpenSettings;

  /// No description provided for @settingsVibrationTestTitle.
  ///
  /// In ko, this message translates to:
  /// **'진동 시험'**
  String get settingsVibrationTestTitle;

  /// No description provided for @vibrationCheckTitle.
  ///
  /// In ko, this message translates to:
  /// **'화면이 꺼져 있어도\n진동이 오는지 확인할게요'**
  String get vibrationCheckTitle;

  /// No description provided for @vibrationCheckDescription.
  ///
  /// In ko, this message translates to:
  /// **'이어폰이 없을 땐 진동이 유일한 알림이에요. 아이폰 설정에 따라 진동이 막혀 있을 수 있어요.'**
  String get vibrationCheckDescription;

  /// No description provided for @vibrationCheckItemNotifications.
  ///
  /// In ko, this message translates to:
  /// **'알림 허용'**
  String get vibrationCheckItemNotifications;

  /// No description provided for @vibrationCheckItemLockScreen.
  ///
  /// In ko, this message translates to:
  /// **'잠금 화면에 표시'**
  String get vibrationCheckItemLockScreen;

  /// No description provided for @vibrationCheckItemSound.
  ///
  /// In ko, this message translates to:
  /// **'알림 사운드'**
  String get vibrationCheckItemSound;

  /// No description provided for @vibrationCheckItemHaptics.
  ///
  /// In ko, this message translates to:
  /// **'햅틱 · 진동'**
  String get vibrationCheckItemHaptics;

  /// No description provided for @vibrationCheckStatusOn.
  ///
  /// In ko, this message translates to:
  /// **'켜짐'**
  String get vibrationCheckStatusOn;

  /// No description provided for @vibrationCheckStatusOff.
  ///
  /// In ko, this message translates to:
  /// **'꺼짐'**
  String get vibrationCheckStatusOff;

  /// No description provided for @vibrationCheckStatusByTest.
  ///
  /// In ko, this message translates to:
  /// **'시험으로 확인'**
  String get vibrationCheckStatusByTest;

  /// No description provided for @vibrationCheckBlockedHint.
  ///
  /// In ko, this message translates to:
  /// **'꺼진 항목을 먼저 켜 주세요. 알림 사운드가 꺼지면 진동도 함께 빠져요. 소리는 나지 않는 알림음이에요.'**
  String get vibrationCheckBlockedHint;

  /// No description provided for @vibrationCheckOpenNotificationSettings.
  ///
  /// In ko, this message translates to:
  /// **'알림 설정 열기'**
  String get vibrationCheckOpenNotificationSettings;

  /// No description provided for @vibrationCheckSendTest.
  ///
  /// In ko, this message translates to:
  /// **'시험 알림 보내기'**
  String get vibrationCheckSendTest;

  /// No description provided for @vibrationCheckLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get vibrationCheckLater;

  /// No description provided for @vibrationCheckScheduleFailed.
  ///
  /// In ko, this message translates to:
  /// **'시험 알림을 보내지 못했어요. 다시 눌러 주세요.'**
  String get vibrationCheckScheduleFailed;

  /// No description provided for @vibrationCheckNotificationTitle.
  ///
  /// In ko, this message translates to:
  /// **'진동 점검'**
  String get vibrationCheckNotificationTitle;

  /// No description provided for @vibrationCheckNotificationBody.
  ///
  /// In ko, this message translates to:
  /// **'진동이 왔나요? 앱으로 돌아와 알려 주세요'**
  String get vibrationCheckNotificationBody;

  /// No description provided for @vibrationCheckWaitingTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금 화면을 잠가 주세요'**
  String get vibrationCheckWaitingTitle;

  /// No description provided for @vibrationCheckWaitingBody.
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초 뒤 도착 알림과 똑같은 알림이 와요. 진동이 오는지 느껴 보세요.'**
  String vibrationCheckWaitingBody(int seconds);

  /// No description provided for @vibrationCheckCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get vibrationCheckCancel;

  /// No description provided for @vibrationCheckNotLockedTitle.
  ///
  /// In ko, this message translates to:
  /// **'화면을 잠그지 않았어요'**
  String get vibrationCheckNotLockedTitle;

  /// No description provided for @vibrationCheckNotLockedBody.
  ///
  /// In ko, this message translates to:
  /// **'앱이 켜져 있으면 실제 도착과 달라 시험이 안 돼요. 버튼을 누른 뒤 바로 화면을 잠가 주세요.'**
  String get vibrationCheckNotLockedBody;

  /// No description provided for @vibrationCheckTryAgain.
  ///
  /// In ko, this message translates to:
  /// **'다시 시험하기'**
  String get vibrationCheckTryAgain;

  /// No description provided for @vibrationCheckAskTitle.
  ///
  /// In ko, this message translates to:
  /// **'방금 알림이 올 때\n진동을 느꼈나요?'**
  String get vibrationCheckAskTitle;

  /// No description provided for @vibrationCheckAskBody.
  ///
  /// In ko, this message translates to:
  /// **'소리는 나지 않는 게 맞아요. 떨림만 확인해 주세요.'**
  String get vibrationCheckAskBody;

  /// No description provided for @vibrationCheckAnswerFelt.
  ///
  /// In ko, this message translates to:
  /// **'느꼈어요'**
  String get vibrationCheckAnswerFelt;

  /// No description provided for @vibrationCheckAnswerNotFelt.
  ///
  /// In ko, this message translates to:
  /// **'못 느꼈어요'**
  String get vibrationCheckAnswerNotFelt;

  /// No description provided for @vibrationCheckAnswerNoNotification.
  ///
  /// In ko, this message translates to:
  /// **'알림이 안 왔어요'**
  String get vibrationCheckAnswerNoNotification;

  /// No description provided for @vibrationCheckGuideHapticsEyebrow.
  ///
  /// In ko, this message translates to:
  /// **'가장 흔한 원인'**
  String get vibrationCheckGuideHapticsEyebrow;

  /// No description provided for @vibrationCheckGuideHapticsTitle.
  ///
  /// In ko, this message translates to:
  /// **'햅틱을 \'항상 재생\'으로'**
  String get vibrationCheckGuideHapticsTitle;

  /// No description provided for @vibrationCheckGuideAccessibilityEyebrow.
  ///
  /// In ko, this message translates to:
  /// **'기기 전체 진동 스위치'**
  String get vibrationCheckGuideAccessibilityEyebrow;

  /// No description provided for @vibrationCheckGuideAccessibilityTitle.
  ///
  /// In ko, this message translates to:
  /// **'진동 켜기'**
  String get vibrationCheckGuideAccessibilityTitle;

  /// No description provided for @vibrationCheckGuideAccessibilityHint.
  ///
  /// In ko, this message translates to:
  /// **'이 스위치가 꺼져 있으면 전화와 알림 진동이 전부 막혀요.'**
  String get vibrationCheckGuideAccessibilityHint;

  /// No description provided for @vibrationCheckGuideFocusEyebrow.
  ///
  /// In ko, this message translates to:
  /// **'마지막 확인'**
  String get vibrationCheckGuideFocusEyebrow;

  /// No description provided for @vibrationCheckGuideFocusTitle.
  ///
  /// In ko, this message translates to:
  /// **'집중 모드에서 이 앱 허용'**
  String get vibrationCheckGuideFocusTitle;

  /// No description provided for @vibrationCheckGuideFocusHint.
  ///
  /// In ko, this message translates to:
  /// **'집중 모드를 쓰지 않는다면 넘어가도 돼요.'**
  String get vibrationCheckGuideFocusHint;

  /// No description provided for @vibrationCheckGuideOpenSettingsHint.
  ///
  /// In ko, this message translates to:
  /// **'\'설정 열기\'는 이 앱 설정 페이지를 열어요. 왼쪽 위 뒤로 버튼으로 설정 첫 화면에 가 주세요.'**
  String get vibrationCheckGuideOpenSettingsHint;

  /// No description provided for @vibrationCheckOpenSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get vibrationCheckOpenSettings;

  /// No description provided for @vibrationCheckGuideChanged.
  ///
  /// In ko, this message translates to:
  /// **'바꿨어요'**
  String get vibrationCheckGuideChanged;

  /// No description provided for @vibrationCheckGuideStillNot.
  ///
  /// In ko, this message translates to:
  /// **'그래도 안 되면'**
  String get vibrationCheckGuideStillNot;

  /// No description provided for @vibrationCheckSuccessTitle.
  ///
  /// In ko, this message translates to:
  /// **'준비됐어요'**
  String get vibrationCheckSuccessTitle;

  /// No description provided for @vibrationCheckSuccessBody.
  ///
  /// In ko, this message translates to:
  /// **'이어폰이 없어도 도착하면\n화면이 꺼진 채로 진동이 와요.'**
  String get vibrationCheckSuccessBody;

  /// No description provided for @vibrationCheckDone.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get vibrationCheckDone;

  /// No description provided for @vibrationCheckStillTitle.
  ///
  /// In ko, this message translates to:
  /// **'다른 앱 알림은 떨리나요?'**
  String get vibrationCheckStillTitle;

  /// No description provided for @vibrationCheckStillBody.
  ///
  /// In ko, this message translates to:
  /// **'메시지가 올 때도 안 떨리면 기기 쪽 설정이에요. 벨소리의 햅틱 패턴이 \'없음\'으로 되어 있지 않은지 확인해 보세요.'**
  String get vibrationCheckStillBody;

  /// No description provided for @vibrationCheckClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get vibrationCheckClose;

  /// No description provided for @iosSettingsRoot.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get iosSettingsRoot;

  /// No description provided for @iosSettingsSoundsAndHaptics.
  ///
  /// In ko, this message translates to:
  /// **'사운드 및 햅틱'**
  String get iosSettingsSoundsAndHaptics;

  /// No description provided for @iosSettingsHaptics.
  ///
  /// In ko, this message translates to:
  /// **'햅틱'**
  String get iosSettingsHaptics;

  /// No description provided for @iosSettingsHapticsAlways.
  ///
  /// In ko, this message translates to:
  /// **'항상 재생'**
  String get iosSettingsHapticsAlways;

  /// No description provided for @iosSettingsHapticsSilentOnly.
  ///
  /// In ko, this message translates to:
  /// **'무음 모드에서 재생'**
  String get iosSettingsHapticsSilentOnly;

  /// No description provided for @iosSettingsHapticsNotInSilent.
  ///
  /// In ko, this message translates to:
  /// **'무음 모드에서 재생 안 함'**
  String get iosSettingsHapticsNotInSilent;

  /// No description provided for @iosSettingsHapticsNever.
  ///
  /// In ko, this message translates to:
  /// **'재생 안 함'**
  String get iosSettingsHapticsNever;

  /// No description provided for @iosSettingsAccessibility.
  ///
  /// In ko, this message translates to:
  /// **'손쉬운 사용'**
  String get iosSettingsAccessibility;

  /// No description provided for @iosSettingsTouch.
  ///
  /// In ko, this message translates to:
  /// **'터치'**
  String get iosSettingsTouch;

  /// No description provided for @iosSettingsTapToWake.
  ///
  /// In ko, this message translates to:
  /// **'탭하여 깨우기'**
  String get iosSettingsTapToWake;

  /// No description provided for @iosSettingsShakeToUndo.
  ///
  /// In ko, this message translates to:
  /// **'흔들어서 실행 취소'**
  String get iosSettingsShakeToUndo;

  /// No description provided for @iosSettingsVibration.
  ///
  /// In ko, this message translates to:
  /// **'진동'**
  String get iosSettingsVibration;

  /// No description provided for @iosSettingsFocus.
  ///
  /// In ko, this message translates to:
  /// **'집중 모드'**
  String get iosSettingsFocus;

  /// No description provided for @iosSettingsFocusMode.
  ///
  /// In ko, this message translates to:
  /// **'사용 중인 모드'**
  String get iosSettingsFocusMode;

  /// No description provided for @iosSettingsFocusAllowApp.
  ///
  /// In ko, this message translates to:
  /// **'허용된 알림 › 앱 추가'**
  String get iosSettingsFocusAllowApp;

  /// No description provided for @iosSettingsRingtone.
  ///
  /// In ko, this message translates to:
  /// **'벨소리'**
  String get iosSettingsRingtone;

  /// No description provided for @iosSettingsRingtoneHapticsNotNone.
  ///
  /// In ko, this message translates to:
  /// **'햅틱 ≠ 없음'**
  String get iosSettingsRingtoneHapticsNotNone;

  /// No description provided for @settingsVibrationCheckTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림이 안 울린다면'**
  String get settingsVibrationCheckTitle;

  /// No description provided for @settingsVibrationCheckSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'진동 점검과 아이폰 설정 안내'**
  String get settingsVibrationCheckSubtitle;

  /// No description provided for @onboardingVibrationCardTitle.
  ///
  /// In ko, this message translates to:
  /// **'진동이 느껴지는지 확인해 보세요'**
  String get onboardingVibrationCardTitle;

  /// No description provided for @onboardingVibrationCardBody.
  ///
  /// In ko, this message translates to:
  /// **'iPhone 진동 설정이 꺼져 있으면 도착해도 아무 느낌이 없어요.'**
  String get onboardingVibrationCardBody;

  /// No description provided for @homeGapNotifications.
  ///
  /// In ko, this message translates to:
  /// **'알림 허용'**
  String get homeGapNotifications;

  /// No description provided for @homeGapLockScreen.
  ///
  /// In ko, this message translates to:
  /// **'잠금 화면 알림'**
  String get homeGapLockScreen;

  /// No description provided for @homeGapVibration.
  ///
  /// In ko, this message translates to:
  /// **'진동'**
  String get homeGapVibration;

  /// No description provided for @settingsLockScreenNotifyTitle.
  ///
  /// In ko, this message translates to:
  /// **'잠금 화면에 표시'**
  String get settingsLockScreenNotifyTitle;

  /// No description provided for @settingsLockScreenNotifyDesc.
  ///
  /// In ko, this message translates to:
  /// **'꺼져 있으면 화면이 꺼진 채 도착했을 때 아무것도 보이지 않아요'**
  String get settingsLockScreenNotifyDesc;

  /// No description provided for @notificationActionDismiss.
  ///
  /// In ko, this message translates to:
  /// **'알림 끄기'**
  String get notificationActionDismiss;

  /// No description provided for @settingsReportTitle.
  ///
  /// In ko, this message translates to:
  /// **'문제 신고'**
  String get settingsReportTitle;

  /// No description provided for @settingsReportSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'불편한 점이나 오류를 메일로 보냅니다'**
  String get settingsReportSubtitle;

  /// No description provided for @reportSheetTitle.
  ///
  /// In ko, this message translates to:
  /// **'문제 신고'**
  String get reportSheetTitle;

  /// No description provided for @reportSheetHint.
  ///
  /// In ko, this message translates to:
  /// **'메일 앱이 열립니다. 내용을 적고 직접 보내 주세요.'**
  String get reportSheetHint;

  /// No description provided for @reportAttachLog.
  ///
  /// In ko, this message translates to:
  /// **'동작 기록 함께 보내기'**
  String get reportAttachLog;

  /// No description provided for @reportAttachLogNote.
  ///
  /// In ko, this message translates to:
  /// **'위치 좌표·등록 장소·설정이 담긴 기록이 첨부됩니다. 보내기 전에 메일에서 확인할 수 있고, 직접 보낼 때만 전송됩니다.'**
  String get reportAttachLogNote;

  /// No description provided for @reportOpenMail.
  ///
  /// In ko, this message translates to:
  /// **'메일 앱 열기'**
  String get reportOpenMail;

  /// No description provided for @reportMailSubject.
  ///
  /// In ko, this message translates to:
  /// **'[이어폰위치알림] 문제 신고'**
  String get reportMailSubject;

  /// No description provided for @reportMailPrompt.
  ///
  /// In ko, this message translates to:
  /// **'어떤 문제가 있었는지 적어 주세요.'**
  String get reportMailPrompt;

  /// No description provided for @reportMailInfoHeader.
  ///
  /// In ko, this message translates to:
  /// **'아래는 확인에 필요한 기기 정보입니다. 지우지 말아 주세요.'**
  String get reportMailInfoHeader;

  /// No description provided for @reportFallbackNotice.
  ///
  /// In ko, this message translates to:
  /// **'메일 계정이 없어 공유 화면으로 열었습니다. 받는 사람은 {address} 입니다.'**
  String reportFallbackNotice(String address);

  /// No description provided for @reportFailed.
  ///
  /// In ko, this message translates to:
  /// **'메일을 열지 못했습니다. 받는 사람 주소를 복사했습니다.'**
  String get reportFailed;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In ko, this message translates to:
  /// **'백업'**
  String get settingsSectionBackup;

  /// No description provided for @settingsBackupExportTitle.
  ///
  /// In ko, this message translates to:
  /// **'장소 내보내기'**
  String get settingsBackupExportTitle;

  /// No description provided for @settingsBackupExportSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'등록한 장소를 파일로 저장하거나 다른 곳으로 보냅니다'**
  String get settingsBackupExportSubtitle;

  /// No description provided for @settingsBackupImportTitle.
  ///
  /// In ko, this message translates to:
  /// **'장소 불러오기'**
  String get settingsBackupImportTitle;

  /// No description provided for @settingsBackupImportSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'내보낸 파일에서 장소를 가져옵니다'**
  String get settingsBackupImportSubtitle;

  /// No description provided for @backupExportEmpty.
  ///
  /// In ko, this message translates to:
  /// **'내보낼 장소가 없습니다'**
  String get backupExportEmpty;

  /// No description provided for @backupExportSubject.
  ///
  /// In ko, this message translates to:
  /// **'이어폰위치알림 장소 백업'**
  String get backupExportSubject;

  /// No description provided for @backupExportCustomSound.
  ///
  /// In ko, this message translates to:
  /// **'내 음원을 쓰는 장소 {count}곳은 기본 알림음으로 담았습니다'**
  String backupExportCustomSound(int count);

  /// No description provided for @backupImportTitle.
  ///
  /// In ko, this message translates to:
  /// **'장소를 불러올까요?'**
  String get backupImportTitle;

  /// No description provided for @backupImportBody.
  ///
  /// In ko, this message translates to:
  /// **'파일에서 장소 {count}곳을 찾았습니다. 지금 등록된 장소는 {existing}곳입니다. 이미 있는 장소는 건너뜁니다.'**
  String backupImportBody(int count, int existing);

  /// No description provided for @backupImportAdd.
  ///
  /// In ko, this message translates to:
  /// **'추가하기'**
  String get backupImportAdd;

  /// No description provided for @backupImportReplace.
  ///
  /// In ko, this message translates to:
  /// **'모두 바꾸기'**
  String get backupImportReplace;

  /// No description provided for @backupCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get backupCancel;

  /// No description provided for @backupReplaceTitle.
  ///
  /// In ko, this message translates to:
  /// **'기존 장소를 모두 지울까요?'**
  String get backupReplaceTitle;

  /// No description provided for @backupReplaceBody.
  ///
  /// In ko, this message translates to:
  /// **'지금 등록된 장소 {existing}곳이 지워지고 파일의 장소로 바뀝니다. 되돌릴 수 없습니다.'**
  String backupReplaceBody(int existing);

  /// No description provided for @backupReplaceConfirm.
  ///
  /// In ko, this message translates to:
  /// **'바꾸기'**
  String get backupReplaceConfirm;

  /// No description provided for @backupImportResult.
  ///
  /// In ko, this message translates to:
  /// **'장소 {added}곳을 불러왔습니다. 건너뜀 {skipped}곳'**
  String backupImportResult(int added, int skipped);

  /// No description provided for @backupImportNone.
  ///
  /// In ko, this message translates to:
  /// **'불러올 새 장소가 없습니다'**
  String get backupImportNone;

  /// No description provided for @backupImportInvalid.
  ///
  /// In ko, this message translates to:
  /// **'이 앱에서 내보낸 장소 파일이 아닙니다'**
  String get backupImportInvalid;

  /// No description provided for @backupImportNewer.
  ///
  /// In ko, this message translates to:
  /// **'더 새로운 버전의 앱에서 만든 파일입니다. 앱을 업데이트한 뒤 다시 불러오세요'**
  String get backupImportNewer;

  /// No description provided for @backupImportReadFailed.
  ///
  /// In ko, this message translates to:
  /// **'파일을 읽지 못했습니다'**
  String get backupImportReadFailed;

  /// No description provided for @proSheetTitle.
  ///
  /// In ko, this message translates to:
  /// **'평생 이용권'**
  String get proSheetTitle;

  /// No description provided for @proSheetSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'구독 아님 · 기기 바꿔도 같은 계정이면 유지'**
  String get proSheetSubtitle;

  /// No description provided for @proSheetBuy.
  ///
  /// In ko, this message translates to:
  /// **'평생 이용권 {price}'**
  String proSheetBuy(String price);

  /// No description provided for @proSheetRestore.
  ///
  /// In ko, this message translates to:
  /// **'이미 구매했나요? 복원하기'**
  String get proSheetRestore;

  /// No description provided for @proSheetColumnFree.
  ///
  /// In ko, this message translates to:
  /// **'무료'**
  String get proSheetColumnFree;

  /// No description provided for @proSheetColumnPro.
  ///
  /// In ko, this message translates to:
  /// **'프로'**
  String get proSheetColumnPro;

  /// No description provided for @proRowPlaces.
  ///
  /// In ko, this message translates to:
  /// **'장소'**
  String get proRowPlaces;

  /// No description provided for @proRowDirections.
  ///
  /// In ko, this message translates to:
  /// **'도착·출발 알림'**
  String get proRowDirections;

  /// No description provided for @proRowSchedules.
  ///
  /// In ko, this message translates to:
  /// **'알림 시간대'**
  String get proRowSchedules;

  /// No description provided for @proRowVibration.
  ///
  /// In ko, this message translates to:
  /// **'진동 세기'**
  String get proRowVibration;

  /// No description provided for @proRowSound.
  ///
  /// In ko, this message translates to:
  /// **'이어폰 알림음'**
  String get proRowSound;

  /// No description provided for @proRowBackup.
  ///
  /// In ko, this message translates to:
  /// **'장소 백업'**
  String get proRowBackup;

  /// No description provided for @proRowAds.
  ///
  /// In ko, this message translates to:
  /// **'광고'**
  String get proRowAds;

  /// No description provided for @proValueOnePlace.
  ///
  /// In ko, this message translates to:
  /// **'1개'**
  String get proValueOnePlace;

  /// No description provided for @proValueUnlimited.
  ///
  /// In ko, this message translates to:
  /// **'제한 없음'**
  String get proValueUnlimited;

  /// No description provided for @proValueDefaultSound.
  ///
  /// In ko, this message translates to:
  /// **'기본 1개'**
  String get proValueDefaultSound;

  /// No description provided for @proValueAllSounds.
  ///
  /// In ko, this message translates to:
  /// **'전체 + 내 음원'**
  String get proValueAllSounds;

  /// No description provided for @proValueAdsOn.
  ///
  /// In ko, this message translates to:
  /// **'있음'**
  String get proValueAdsOn;

  /// No description provided for @proValueAdsOff.
  ///
  /// In ko, this message translates to:
  /// **'없음'**
  String get proValueAdsOff;

  /// No description provided for @proUnlockAction.
  ///
  /// In ko, this message translates to:
  /// **'평생 이용권으로 열기'**
  String get proUnlockAction;

  /// No description provided for @proLockedSounds.
  ///
  /// In ko, this message translates to:
  /// **'알림음 전체 · 내 음원'**
  String get proLockedSounds;

  /// No description provided for @proLockedPlaces.
  ///
  /// In ko, this message translates to:
  /// **'장소를 더 등록하려면'**
  String get proLockedPlaces;

  /// No description provided for @proLockedBackup.
  ///
  /// In ko, this message translates to:
  /// **'장소 백업 · 가져오기'**
  String get proLockedBackup;

  /// No description provided for @proLockedExamplePlaceHome.
  ///
  /// In ko, this message translates to:
  /// **'집'**
  String get proLockedExamplePlaceHome;

  /// No description provided for @proLockedExamplePlaceStation.
  ///
  /// In ko, this message translates to:
  /// **'역'**
  String get proLockedExamplePlaceStation;

  /// No description provided for @proCardTitle.
  ///
  /// In ko, this message translates to:
  /// **'장소를 제한 없이 등록하세요'**
  String get proCardTitle;

  /// No description provided for @proCardSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'알림음 전체 · 장소 백업 · 광고 없음'**
  String get proCardSubtitle;

  /// No description provided for @proCardUsage.
  ///
  /// In ko, this message translates to:
  /// **'장소 {count}/{limit} 사용 중'**
  String proCardUsage(int count, int limit);

  /// No description provided for @proRowLifetime.
  ///
  /// In ko, this message translates to:
  /// **'평생 이용권'**
  String get proRowLifetime;

  /// No description provided for @proOwnedSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'모든 기능이 열려 있어요'**
  String get proOwnedSubtitle;

  /// No description provided for @proDeviceLimitReached.
  ///
  /// In ko, this message translates to:
  /// **'기기 한도에 도달했어요'**
  String get proDeviceLimitReached;

  /// No description provided for @proPriceLoading.
  ///
  /// In ko, this message translates to:
  /// **'가격 확인 중…'**
  String get proPriceLoading;

  /// No description provided for @proProductUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'지금은 구매할 수 없어요. 잠시 뒤 다시 시도해 주세요'**
  String get proProductUnavailable;

  /// No description provided for @proPurchasePending.
  ///
  /// In ko, this message translates to:
  /// **'결제가 확인되면 열려요'**
  String get proPurchasePending;

  /// No description provided for @proPurchaseDone.
  ///
  /// In ko, this message translates to:
  /// **'평생 이용권이 열렸어요'**
  String get proPurchaseDone;

  /// No description provided for @proPurchaseFailed.
  ///
  /// In ko, this message translates to:
  /// **'결제를 마치지 못했어요'**
  String get proPurchaseFailed;

  /// No description provided for @proRestoreNone.
  ///
  /// In ko, this message translates to:
  /// **'복원할 구매가 없어요'**
  String get proRestoreNone;

  /// No description provided for @proRestoreDone.
  ///
  /// In ko, this message translates to:
  /// **'구매를 복원했어요'**
  String get proRestoreDone;

  /// No description provided for @proChipFree.
  ///
  /// In ko, this message translates to:
  /// **'FREE'**
  String get proChipFree;

  /// No description provided for @proChipPro.
  ///
  /// In ko, this message translates to:
  /// **'PRO'**
  String get proChipPro;

  /// No description provided for @proInfoTitle.
  ///
  /// In ko, this message translates to:
  /// **'이용권 정보'**
  String get proInfoTitle;

  /// No description provided for @proInfoStatus.
  ///
  /// In ko, this message translates to:
  /// **'상태'**
  String get proInfoStatus;

  /// No description provided for @proInfoStatusActive.
  ///
  /// In ko, this message translates to:
  /// **'사용 중'**
  String get proInfoStatusActive;

  /// No description provided for @proInfoSource.
  ///
  /// In ko, this message translates to:
  /// **'열린 방식'**
  String get proInfoSource;

  /// No description provided for @proSourcePurchase.
  ///
  /// In ko, this message translates to:
  /// **'구매'**
  String get proSourcePurchase;

  /// No description provided for @proInfoPurchasedAt.
  ///
  /// In ko, this message translates to:
  /// **'구매일'**
  String get proInfoPurchasedAt;

  /// No description provided for @proInfoOrderId.
  ///
  /// In ko, this message translates to:
  /// **'주문 번호'**
  String get proInfoOrderId;

  /// No description provided for @proInfoUnknown.
  ///
  /// In ko, this message translates to:
  /// **'확인 중'**
  String get proInfoUnknown;

  /// No description provided for @proInfoNotePurchase.
  ///
  /// In ko, this message translates to:
  /// **'이 기기의 Google Play 계정으로 구매됐어요. 기기를 바꿔도 같은 계정이면 \"구매 복원\"으로 다시 열려요.'**
  String get proInfoNotePurchase;

  /// No description provided for @proInfoRestore.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get proInfoRestore;

  /// No description provided for @proSheetRedeem.
  ///
  /// In ko, this message translates to:
  /// **'프로모션 코드 사용'**
  String get proSheetRedeem;

  /// No description provided for @homeStatusSheetTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금 상태'**
  String get homeStatusSheetTitle;

  /// No description provided for @homeStatusWatchingDescription.
  ///
  /// In ko, this message translates to:
  /// **'켜 둔 장소에 도착하거나 출발하면 알려요'**
  String get homeStatusWatchingDescription;

  /// No description provided for @homeStatusOffDescription.
  ///
  /// In ko, this message translates to:
  /// **'켜진 장소가 있는데 감시가 멈춰 있어요. 위치 권한을 확인해 주세요'**
  String get homeStatusOffDescription;

  /// No description provided for @homeStatusCheckingDescription.
  ///
  /// In ko, this message translates to:
  /// **'감시 상태를 확인하고 있어요'**
  String get homeStatusCheckingDescription;

  /// No description provided for @homeStatusIdleDescription.
  ///
  /// In ko, this message translates to:
  /// **'켜진 장소가 없어요. 장소를 켜면 감시가 시작돼요'**
  String get homeStatusIdleDescription;

  /// No description provided for @homeAudioHeadphonesDescription.
  ///
  /// In ko, this message translates to:
  /// **'이어폰으로 소리와 진동이 와요'**
  String get homeAudioHeadphonesDescription;

  /// No description provided for @homeAudioVibrationOnlyDescription.
  ///
  /// In ko, this message translates to:
  /// **'이어폰이 없어서 진동으로만 알려요'**
  String get homeAudioVibrationOnlyDescription;

  /// No description provided for @homeStatusFixButton.
  ///
  /// In ko, this message translates to:
  /// **'권한 확인하러 가기'**
  String get homeStatusFixButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
