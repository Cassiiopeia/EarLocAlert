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

  /// No description provided for @settingsPreviewTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림 미리보기'**
  String get settingsPreviewTitle;

  /// No description provided for @settingsPreviewSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'알림 화면과 진동을 지금 확인합니다'**
  String get settingsPreviewSubtitle;

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

  /// No description provided for @diagnosticsExportEmpty.
  ///
  /// In ko, this message translates to:
  /// **'내보낼 기록이 없습니다'**
  String get diagnosticsExportEmpty;

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

  /// No description provided for @routeDeletedSound.
  ///
  /// In ko, this message translates to:
  /// **'삭제된 음원 (기본음으로 알림)'**
  String get routeDeletedSound;

  /// No description provided for @routePreviewPlaceName.
  ///
  /// In ko, this message translates to:
  /// **'테스트 장소'**
  String get routePreviewPlaceName;

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

  /// No description provided for @alertDismissedConfirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get alertDismissedConfirm;

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
  /// **'첫 장소를 등록해보세요'**
  String get placeEmptyTitle;

  /// No description provided for @placeEmptyBody.
  ///
  /// In ko, this message translates to:
  /// **'내릴 정류장, 약속 장소, 집 —\n도착하거나 떠날 때 조용히 알려드립니다.'**
  String get placeEmptyBody;

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
