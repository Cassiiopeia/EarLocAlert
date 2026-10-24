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
  String get languageFollowDevice => 'Use device language';

  @override
  String languageFollowDeviceHint(String language) {
    return 'Currently $language';
  }

  @override
  String get languageChanged => 'Language changed';

  @override
  String get languageUndo => 'Undo';

  @override
  String get permissionContinue => 'Continue';

  @override
  String get permissionLocalOnlyFootnote =>
      'Your location stays on this device and is never sent anywhere.';

  @override
  String get permissionLocationTitle => 'Location permission needed';

  @override
  String get permissionLocationBody =>
      'Used to pick places on the map for your alerts and to show roughly where you are now.';

  @override
  String get permissionBackgroundTitle => 'Allow location all the time';

  @override
  String get permissionBackgroundBody =>
      'To alert you on arrival and departure without keeping the app open, the app has to check your location in the background.\n\nWithout it you would have to keep watching the screen, which defeats the purpose of alerts.';

  @override
  String get permissionBackgroundActionAndroid =>
      'Allow all the time in Settings';

  @override
  String get permissionBackgroundFootnoteAndroid =>
      'In settings, change the location permission to \"Allow all the time\".\nYour location stays on this device and is never sent anywhere.';

  @override
  String get permissionNotificationTitle => 'Notification permission needed';

  @override
  String get permissionNotificationBody =>
      'Used to let you know when you arrive or leave.';

  @override
  String get permissionReliabilityTitle => 'So you never miss an alert';

  @override
  String get permissionReliabilityBody =>
      'When your phone is in power saving or you are using another app, arrival alerts can come late or show up only as a small notification.\n\nTurn on all three and the full-screen alert stays on until you dismiss it.\n\n• Unrestricted battery use — alerts on time even in power saving\n• Display over other apps — the alert screen appears even while you watch a video\n• Full-screen notifications — wakes the screen when it is off';

  @override
  String get permissionReliabilityAction => 'Turn on all three';

  @override
  String get permissionReliabilityFootnote =>
      'Settings screens will open one after another. If you skip, the alert screen will not appear on its own, so you would have to tap the notification to open the app and stop the vibration.';

  @override
  String get permissionOpenSettingsTitle => 'Change it in Settings';

  @override
  String get permissionOpenSettingsBody =>
      'The app can\'t ask for this again. Open Settings and change it like this.';

  @override
  String get permissionOpenSettingsAction => 'Open Settings';

  @override
  String get permissionSettingsLocationRow =>
      'Location → While Using the App or Always';

  @override
  String get permissionSettingsBackgroundRowIos => 'Location → Always';

  @override
  String get permissionSettingsBackgroundRowAndroid =>
      'Location → Allow all the time';

  @override
  String get permissionSettingsNotificationRow =>
      'Notifications → Allow Notifications';

  @override
  String get permissionSettingsReturnHintIos =>
      'After changing it, tap ◀ with the app name at the top left to come back. Changing the location permission may restart the app.';

  @override
  String get permissionSettingsReturnHintAndroid =>
      'After changing it, use the back button to return to the app.';

  @override
  String get permissionDoneTitle => 'All set';

  @override
  String get permissionDoneBody =>
      'Add a place and you will be alerted when you arrive or leave.';

  @override
  String get permissionDoneAction => 'Get started';

  @override
  String get onboardingSkip => 'Not now';

  @override
  String get onboardingErrorTitle => 'Could not check permission status';

  @override
  String get onboardingErrorHint => 'Please try again in a moment.';

  @override
  String get onboardingRetry => 'Try again';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAlert => 'Alerts';

  @override
  String get settingsVibrationTitle => 'Vibration strength';

  @override
  String get settingsVibrationSubtitle =>
      'Without earphones, alerts use vibration only';

  @override
  String get settingsVolumeTitle => 'Alert sound volume';

  @override
  String get settingsVolumeSubtitle => 'How loud it plays in your earphones';

  @override
  String get settingsSectionReach => 'Permissions for reliable alerts';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionTroubleshoot => 'Troubleshooting';

  @override
  String get settingsDiagnosticsTitle => 'Activity log';

  @override
  String get settingsDiagnosticsSubtitle =>
      'View and export a record of when and why alerts fired';

  @override
  String get settingsPermissionGranted => 'Allowed';

  @override
  String get settingsPermNotifyTitle => 'Show notifications';

  @override
  String get settingsPermNotifyDesc =>
      'Without it, no alert appears when you arrive';

  @override
  String get settingsPermBatteryTitle => 'Unrestricted battery use';

  @override
  String get settingsPermBatteryDesc =>
      'Without it, alerts may be late or missed in power saving';

  @override
  String get settingsPermOverlayTitle => 'Display over other apps';

  @override
  String get settingsPermOverlayDesc =>
      'Without it, the alert screen will not appear while you use another app';

  @override
  String get settingsPermFullScreenTitle => 'Full-screen notifications';

  @override
  String get settingsPermFullScreenDesc =>
      'Without it, the alert screen will not appear while the screen is off';

  @override
  String get diagnosticsTitle => 'Activity log';

  @override
  String get diagnosticsRefresh => 'Refresh';

  @override
  String get diagnosticsClear => 'Clear';

  @override
  String get diagnosticsCancel => 'Cancel';

  @override
  String get diagnosticsExport => 'Export';

  @override
  String get diagnosticsExportSubject => 'EarLocAlert activity log';

  @override
  String get diagnosticsCopied => 'Copied to clipboard';

  @override
  String get diagnosticsClearTitle => 'Clear the log?';

  @override
  String get diagnosticsClearBody => 'A cleared log cannot be restored.';

  @override
  String diagnosticsHeader(int lineCount, String size, String maxSize) {
    return '$lineCount entries · $size / max $maxSize\nStored only on this device and never sent. When full, the oldest entries are deleted first.';
  }

  @override
  String get diagnosticsReadFailed => 'Could not read the log.';

  @override
  String get diagnosticsEmpty =>
      'No log entries yet.\nThey will appear when you reopen the app or monitoring starts.';

  @override
  String get diagnosticsCopyAll => 'Copy all';

  @override
  String get diagnosticsAppState => 'App state';

  @override
  String get diagnosticsAppStateHint =>
      'Permissions, places, settings and device state. Included when you export.';

  @override
  String get diagnosticsSearchHint => 'Search tag, place or text';

  @override
  String diagnosticsProblemsOnly(int count) {
    return 'Problems $count';
  }

  @override
  String get diagnosticsAllSources => 'All';

  @override
  String get diagnosticsSourceApp => 'App';

  @override
  String get diagnosticsSourceBackground => 'Background';

  @override
  String get diagnosticsSourceNative => 'Native';

  @override
  String get diagnosticsSourceIos => 'iOS';

  @override
  String diagnosticsShownCount(int shown) {
    return 'Showing $shown';
  }

  @override
  String diagnosticsPeriod(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String get diagnosticsNoMatch => 'No entries match.';

  @override
  String get routeDeletedSound => 'Deleted sound (plays the default)';

  @override
  String get notificationChannelName => 'Arrival and departure alerts';

  @override
  String get notificationChannelDescription =>
      'Alerts you when you arrive at or leave a saved place';

  @override
  String get notificationArrived => 'You\'ve arrived';

  @override
  String get notificationLeft => 'You\'ve left';

  @override
  String get alertScreenLeft => 'You\'ve left';

  @override
  String get alertScreenArrived => 'You\'ve arrived';

  @override
  String alertScreenTimeAm(String hour, String minute) {
    return '$hour:$minute AM';
  }

  @override
  String alertScreenTimePm(String hour, String minute) {
    return '$hour:$minute PM';
  }

  @override
  String get alertScreenRouteHeadphones => 'Alerting via earphones';

  @override
  String get alertScreenRouteSoundFailed =>
      'Couldn\'t play sound — alerting by vibration';

  @override
  String get alertScreenRouteVibrationOnly => 'Alerting by vibration only';

  @override
  String get alertScreenDismiss => 'Dismiss';

  @override
  String get alertAlarmOpenApp => 'Open app';

  @override
  String alertScreenRadius(int meters) {
    return 'Radius $meters m';
  }

  @override
  String get alertNotificationChannelName => 'Active alert';

  @override
  String get alertNotificationChannelDescription =>
      'A notification that brings you back to the alert screen';

  @override
  String get alertDismissedTitle => 'Alert dismissed';

  @override
  String get volumeTitle => 'Alert sound volume';

  @override
  String get volumeDescription =>
      'If the system volume is lower than this when an alert rings, it is raised to this level and restored when you dismiss it.';

  @override
  String get volumePreviewStop => 'Stop preview';

  @override
  String get volumePreviewNoHeadphones =>
      'Earphones aren\'t connected, so you can\'t preview.';

  @override
  String get volumePreviewFailed => 'Playback failed.';

  @override
  String get vibrationTitle => 'Vibration strength';

  @override
  String get vibrationDescription =>
      'Without earphones, alerts use vibration only. Pick a strength to feel it once.';

  @override
  String get vibrationWeak => 'Light';

  @override
  String get vibrationNormal => 'Medium';

  @override
  String get vibrationStrong => 'Strong';

  @override
  String get vibrationWeakHint => 'Too quiet for others nearby to hear';

  @override
  String get vibrationNormalHint => 'Default';

  @override
  String get vibrationStrongHint => 'Felt even in a pocket or bag';

  @override
  String get soundPreview => 'Preview';

  @override
  String get soundCancel => 'Cancel';

  @override
  String get soundDelete => 'Delete';

  @override
  String get soundDone => 'Done';

  @override
  String get soundPickerTitle => 'Alert sound';

  @override
  String get soundPickerPresetHeader => 'Built-in sounds';

  @override
  String soundPickerCustomHeader(int count, int max) {
    return 'My sounds  $count/$max';
  }

  @override
  String get soundPickerCustomEmpty =>
      'You can add audio files from your device.';

  @override
  String get soundPickerAdd => 'Add sound';

  @override
  String get soundPickerChecking => 'Checking…';

  @override
  String get soundPickerHeadphoneNotice =>
      'Connect earphones to listen. Alert sounds only play when earphones are connected.';

  @override
  String get soundPreviewFailed => 'This sound can\'t be played';

  @override
  String get soundSaveFailed =>
      'Couldn\'t save the sound. Please try again in a moment.';

  @override
  String get soundDeleteTitle => 'Delete this sound?';

  @override
  String soundDeleteBody(String name) {
    return '$name\n\nPlaces using this sound will alert with the default sound.';
  }

  @override
  String soundDurationMinutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String soundImportLimitReached(int max) {
    return 'You can add up to $max sounds. Delete ones you don\'t use and try again.';
  }

  @override
  String soundImportNoExtension(String allowed) {
    return 'This file has no extension. Only $allowed formats are supported.';
  }

  @override
  String soundImportUnsupported(String extension, String allowed) {
    return 'The $extension format isn\'t supported. Only $allowed are supported.';
  }

  @override
  String soundImportTooLarge(String size, String max) {
    return 'The file is too large ($size / max $max).';
  }

  @override
  String soundImportTooLong(String duration, String max) {
    return 'This file is too long ($duration / max $max). Alert sounds repeat, so a short one is fine.';
  }

  @override
  String get soundImportNotPlayable =>
      'This file can\'t be played. Please choose another one.';

  @override
  String get soundPresetDefault => 'Default';

  @override
  String get soundPresetBell => 'Bell';

  @override
  String get soundPresetElectronic => 'Electronic';

  @override
  String get soundPresetSiren => 'Siren';

  @override
  String get soundPresetChime => 'Chime';

  @override
  String get placeSearchUnnamed => 'Unnamed place';

  @override
  String get placePickerTitle => 'Pick on map';

  @override
  String get placeMyLocation => 'My location';

  @override
  String get placeSearchHint => 'Search places or addresses';

  @override
  String get placeSearchUnavailable =>
      'Search is unavailable — move the map to set the location';

  @override
  String get placePickerPinHint => 'Move the map to place the pin';

  @override
  String get placePickerConfirm => 'Use this location';

  @override
  String get placeDirectionEnter => 'Arrival alert';

  @override
  String get placeDirectionExit => 'Departure alert';

  @override
  String get placeDirectionBoth => 'Arrival & departure';

  @override
  String placeRadiusInfo(String direction, int meters) {
    return '$direction · Radius $meters m';
  }

  @override
  String placeDeleted(String name) {
    return '\'$name\' deleted';
  }

  @override
  String get placeUndo => 'Undo';

  @override
  String get placeSwipeDeleteLabel => 'Delete';

  @override
  String get placeFormDelete => 'Delete this place';

  @override
  String get placeFormDeleteTitle => 'Delete this place?';

  @override
  String placeFormDeleteBody(String name) {
    return '\'$name\' will be removed from your list. You can undo right after deleting.';
  }

  @override
  String get placeDeleteCancel => 'Cancel';

  @override
  String get placeFormLeaveTitle => 'Leave without saving?';

  @override
  String get placeFormLeaveBody => 'Your changes will be lost.';

  @override
  String get placeFormKeepEditing => 'Keep editing';

  @override
  String get placeFormLeave => 'Leave';

  @override
  String get placeFormTitleNew => 'Add place';

  @override
  String get placeFormTitleEdit => 'Edit place';

  @override
  String get placeFormNameLabel => 'Name';

  @override
  String get placeFormNameHint => 'e.g. My stop, meeting spot';

  @override
  String get placeFormLocationLabel => 'Location';

  @override
  String get placeFormPickOnMap => 'Pick on map';

  @override
  String get placeFormRepickOnMap => 'Pick again on map';

  @override
  String get placeFormNoLocation => 'No location picked yet';

  @override
  String placeFormCoordinates(String value) {
    return 'Coordinates  $value';
  }

  @override
  String get placeFormCoordinatesManual => 'Enter coordinates';

  @override
  String get placeFormLatitude => 'Latitude';

  @override
  String get placeFormLongitude => 'Longitude';

  @override
  String get placeFormRadiusLabel => 'Alert radius';

  @override
  String placeFormRadiusValue(int meters) {
    return '$meters m';
  }

  @override
  String get placeFormTimingLabel => 'Alert timing';

  @override
  String get placeFormTimingEnter => 'Arrival';

  @override
  String get placeFormTimingExit => 'Departure';

  @override
  String get placeFormTimingBoth => 'Both';

  @override
  String get placeFormSoundTitle => 'Sound alert on earphones';

  @override
  String get placeFormSoundDescription =>
      'Plays sound only when earphones (wired or Bluetooth) are connected.\nNever plays through the speaker.';

  @override
  String get placeFormSoundLabel => 'Alert sound';

  @override
  String get placeFormCustomSound => 'My sound';

  @override
  String get placeFormSubmitNew => 'Add';

  @override
  String get placeFormSubmitSave => 'Save';

  @override
  String get placeErrorEmptyName => 'Enter a name';

  @override
  String placeErrorRadius(int min, int max) {
    return 'Radius must be between $min m and $max m';
  }

  @override
  String get placeErrorCoordinates => 'The location coordinates are not valid';

  @override
  String placeErrorLimit(int max) {
    return 'You can add up to $max places';
  }

  @override
  String get placeErrorEmptyWindow =>
      'The start and end times are the same. To alert all day, remove the hours';

  @override
  String get placeErrorNoDays => 'Pick at least one day';

  @override
  String get placeEmptyTitle => 'Add your first place';

  @override
  String get placeEmptyAction => 'Add place';

  @override
  String get placeHomeLocationUnavailable =>
      'Can\'t get your current location. Check the location permission';

  @override
  String get placeLocationSlow =>
      'Finding your location is taking a while. Try again in a moment';

  @override
  String get placeHomeStatusWatching => 'Monitoring';

  @override
  String get placeHomeStatusOff => 'Monitoring off';

  @override
  String get placeHomeStatusChecking => 'Checking';

  @override
  String get placeHomeStatusIdle => 'Standby';

  @override
  String get placeHomeAudioHeadphones => 'Earphones';

  @override
  String get placeHomeAudioVibrationOnly => 'Vibration only';

  @override
  String get placeHomeWeakTitle => 'You may miss alerts';

  @override
  String get placeHomeWeakPowerSaving =>
      'Alerts get weaker in power saving or while using other apps';

  @override
  String placeHomeWeakMissing(String items) {
    return 'Turned off: $items — tap to turn on';
  }

  @override
  String get placeHomeAddPlace => 'Add place';

  @override
  String get placeHomeLoadFailed => 'Couldn\'t load places';

  @override
  String get placeHomeSettings => 'Settings';

  @override
  String get scheduleTitle => 'Alert schedule';

  @override
  String get scheduleAlways => 'Always alert';

  @override
  String get scheduleAlwaysHint =>
      'Alerts at any time — add a time range to limit them';

  @override
  String get scheduleAdd => 'Add time range';

  @override
  String get scheduleRemove => 'Delete this time range';

  @override
  String get scheduleSheetAddTitle => 'Add hours';

  @override
  String get scheduleSheetEditTitle => 'Edit hours';

  @override
  String get scheduleDaysLabel => 'Days';

  @override
  String get scheduleEveryday => 'Every day';

  @override
  String get scheduleWeekdays => 'Weekdays';

  @override
  String get scheduleWeekends => 'Weekends';

  @override
  String get scheduleDayMon => 'Mon';

  @override
  String get scheduleDayTue => 'Tue';

  @override
  String get scheduleDayWed => 'Wed';

  @override
  String get scheduleDayThu => 'Thu';

  @override
  String get scheduleDayFri => 'Fri';

  @override
  String get scheduleDaySat => 'Sat';

  @override
  String get scheduleDaySun => 'Sun';

  @override
  String get scheduleStart => 'Start';

  @override
  String get scheduleEnd => 'End';

  @override
  String scheduleCrossesMidnight(String window) {
    return 'The end is earlier than the start, so this runs past midnight — $window';
  }

  @override
  String get scheduleSameStartEnd =>
      'Start and end are the same. To alert all day, don\'t add a time range.';

  @override
  String get scheduleSave => 'Save';

  @override
  String get scheduleAddButton => 'Add';

  @override
  String get settingsWatchTitle => 'Get alerts on your watch';

  @override
  String get settingsWatchSubtitle =>
      'How to receive arrival alerts on a smartwatch';

  @override
  String get watchGuideIntro =>
      'If you wear a smartwatch, you can get alerts on it too. Turn on one setting on the watch side.';

  @override
  String get watchGuideAndroidStep1 =>
      'On your phone, open your watch app, such as Galaxy Wearable';

  @override
  String get watchGuideAndroidStep2 =>
      'Go to Watch settings → Notifications → App notifications';

  @override
  String watchGuideAndroidStep3(String appName) {
    return 'Turn on \"$appName\" in the list';
  }

  @override
  String get watchGuideIosStep1 => 'On your iPhone, open the Watch app';

  @override
  String get watchGuideIosStep2 => 'Go to Notifications';

  @override
  String watchGuideIosStep3(String appName) {
    return 'Turn on \"$appName\" if it appears. Alerts reach the watch while the iPhone is locked';
  }

  @override
  String get watchGuideNote =>
      'How the watch buzzes can vary with your watch settings.';

  @override
  String get watchGuideConfirm => 'Got it';

  @override
  String get settingsThemeTitle => 'Appearance';

  @override
  String get themeSystem => 'Match device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSheetHint =>
      'The alert screen always stays dark so it never glares.';

  @override
  String get themeChanged => 'Appearance changed';

  @override
  String get themeUndo => 'Undo';

  @override
  String get placeFormSaveFailed =>
      'Couldn\'t save. Please try again in a moment.';

  @override
  String get scheduleCancel => 'Cancel';

  @override
  String scheduleWindow(String days, String start, String end) {
    return '$days $start ~ $end';
  }

  @override
  String scheduleWindowNextDay(String days, String start, String end) {
    return '$days $start ~ $end (next day)';
  }

  @override
  String scheduleTimeRange(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String scheduleTimeRangeNextDay(String start, String end) {
    return '$start ~ $end (next day)';
  }

  @override
  String scheduleMore(String first, int count) {
    return '$first +$count more';
  }

  @override
  String get appUpdateReady => 'A new version is ready';

  @override
  String get appUpdateRestart => 'Restart';

  @override
  String get settingsVersionTitle => 'App version';

  @override
  String get settingsVersionCheck => 'Check for updates';

  @override
  String get appUpdateNone => 'No update is available right now';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsTermsTitle => 'Terms of Service';

  @override
  String get settingsPrivacyTitle => 'Privacy Policy';

  @override
  String get settingsLicensesTitle => 'Open-source licenses';

  @override
  String get settingsAdPrivacyTitle => 'Ad privacy settings';

  @override
  String get settingsAdPrivacySubtitle =>
      'Review or change your ad consent choices';

  @override
  String get settingsOpenLinkFailed =>
      'Couldn\'t open the link. Please check that a browser is installed.';

  @override
  String get settingsLockAlarmTitle => 'Lock screen alarm';

  @override
  String get settingsLockAlarmOn =>
      'When the screen is off, the alarm covers the whole lock screen';

  @override
  String get settingsLockAlarmNotDetermined =>
      'Allow it to cover the whole lock screen with an alarm when the screen is off';

  @override
  String get settingsLockAlarmDenied =>
      'Off. Allow alarms in Settings to cover the whole lock screen when you arrive';

  @override
  String get settingsLockAlarmNeedsNewerOs =>
      'A full-screen alarm needs iOS 26 or later. For now, you will be alerted with a notification and vibration.';

  @override
  String get settingsLockAlarmAllow => 'Allow';

  @override
  String get settingsLockAlarmOpenSettings => 'Open Settings';

  @override
  String get settingsVibrationTestTitle => 'Vibration test';

  @override
  String get vibrationCheckTitle =>
      'Let\'s check you feel\nalerts with the screen off';

  @override
  String get vibrationCheckDescription =>
      'Without earphones, vibration is your only alert. Your iPhone settings may be blocking it.';

  @override
  String get vibrationCheckItemNotifications => 'Allow Notifications';

  @override
  String get vibrationCheckItemLockScreen => 'Show on Lock Screen';

  @override
  String get vibrationCheckItemSound => 'Notification Sounds';

  @override
  String get vibrationCheckItemHaptics => 'Haptics · Vibration';

  @override
  String get vibrationCheckStatusOn => 'On';

  @override
  String get vibrationCheckStatusOff => 'Off';

  @override
  String get vibrationCheckStatusByTest => 'Checked by test';

  @override
  String get vibrationCheckBlockedHint =>
      'Turn on the items that are off first. If notification sounds are off, vibration goes too. The sound itself is silent.';

  @override
  String get vibrationCheckOpenNotificationSettings =>
      'Open notification settings';

  @override
  String get vibrationCheckSendTest => 'Send test alert';

  @override
  String get vibrationCheckLater => 'Later';

  @override
  String get vibrationCheckScheduleFailed =>
      'Couldn\'t send the test alert. Please tap again.';

  @override
  String get vibrationCheckNotificationTitle => 'Vibration check';

  @override
  String get vibrationCheckNotificationBody =>
      'Did it vibrate? Come back to the app and tell us';

  @override
  String get vibrationCheckWaitingTitle => 'Lock your screen now';

  @override
  String vibrationCheckWaitingBody(int seconds) {
    return 'In $seconds seconds, an alert just like an arrival alert will come. Feel for the vibration.';
  }

  @override
  String get vibrationCheckCancel => 'Cancel';

  @override
  String get vibrationCheckNotLockedTitle => 'The screen wasn\'t locked';

  @override
  String get vibrationCheckNotLockedBody =>
      'With the app open, the test doesn\'t match a real arrival. Lock the screen right after tapping the button.';

  @override
  String get vibrationCheckTryAgain => 'Test again';

  @override
  String get vibrationCheckAskTitle =>
      'Did you feel a vibration\nwhen the alert came?';

  @override
  String get vibrationCheckAskBody =>
      'No sound is expected. Just check for the buzz.';

  @override
  String get vibrationCheckAnswerFelt => 'I felt it';

  @override
  String get vibrationCheckAnswerNotFelt => 'I didn\'t';

  @override
  String get vibrationCheckAnswerNoNotification => 'No alert came';

  @override
  String get vibrationCheckGuideHapticsEyebrow => 'Most common cause';

  @override
  String get vibrationCheckGuideHapticsTitle =>
      'Set Haptics to \'Always Play\'';

  @override
  String get vibrationCheckGuideAccessibilityEyebrow =>
      'Device-wide vibration switch';

  @override
  String get vibrationCheckGuideAccessibilityTitle => 'Turn on Vibration';

  @override
  String get vibrationCheckGuideAccessibilityHint =>
      'If this switch is off, all call and notification vibrations are blocked.';

  @override
  String get vibrationCheckGuideFocusEyebrow => 'Last check';

  @override
  String get vibrationCheckGuideFocusTitle => 'Allow this app in Focus';

  @override
  String get vibrationCheckGuideFocusHint =>
      'Skip this if you don\'t use Focus.';

  @override
  String get vibrationCheckGuideOpenSettingsHint =>
      '\'Open Settings\' opens this app\'s page. Use the back button at the top left to reach the main Settings screen.';

  @override
  String get vibrationCheckOpenSettings => 'Open Settings';

  @override
  String get vibrationCheckGuideChanged => 'Done';

  @override
  String get vibrationCheckGuideStillNot => 'Still not working';

  @override
  String get vibrationCheckSuccessTitle => 'All set';

  @override
  String get vibrationCheckSuccessBody =>
      'Even without earphones, you\'ll feel\na vibration when you arrive, screen off.';

  @override
  String get vibrationCheckDone => 'OK';

  @override
  String get vibrationCheckStillTitle => 'Do other apps\' alerts vibrate?';

  @override
  String get vibrationCheckStillBody =>
      'If messages don\'t vibrate either, it\'s a device setting. Check that the ringtone\'s haptic pattern isn\'t set to \'None\'.';

  @override
  String get vibrationCheckClose => 'Close';

  @override
  String get iosSettingsRoot => 'Settings';

  @override
  String get iosSettingsSoundsAndHaptics => 'Sounds & Haptics';

  @override
  String get iosSettingsHaptics => 'Haptics';

  @override
  String get iosSettingsHapticsAlways => 'Always Play';

  @override
  String get iosSettingsHapticsSilentOnly => 'Play in Silent Mode';

  @override
  String get iosSettingsHapticsNotInSilent => 'Don\'t Play in Silent Mode';

  @override
  String get iosSettingsHapticsNever => 'Never Play';

  @override
  String get iosSettingsAccessibility => 'Accessibility';

  @override
  String get iosSettingsTouch => 'Touch';

  @override
  String get iosSettingsTapToWake => 'Tap to Wake';

  @override
  String get iosSettingsShakeToUndo => 'Shake to Undo';

  @override
  String get iosSettingsVibration => 'Vibration';

  @override
  String get iosSettingsFocus => 'Focus';

  @override
  String get iosSettingsFocusMode => 'Your Focus';

  @override
  String get iosSettingsFocusAllowApp => 'Allowed Notifications › Add App';

  @override
  String get iosSettingsRingtone => 'Ringtone';

  @override
  String get iosSettingsRingtoneHapticsNotNone => 'Haptics ≠ None';

  @override
  String get settingsVibrationCheckTitle => 'If alerts don\'t buzz';

  @override
  String get settingsVibrationCheckSubtitle =>
      'Vibration check and iPhone settings guide';

  @override
  String get onboardingVibrationCardTitle =>
      'Check that you can feel the vibration';

  @override
  String get onboardingVibrationCardBody =>
      'If vibration is off on your iPhone, you won\'t feel anything when you arrive.';

  @override
  String get homeGapNotifications => 'Notifications';

  @override
  String get homeGapLockScreen => 'Lock Screen notifications';

  @override
  String get homeGapVibration => 'Vibration';

  @override
  String get settingsLockScreenNotifyTitle => 'Show on Lock Screen';

  @override
  String get settingsLockScreenNotifyDesc =>
      'When off, nothing shows if you arrive with the screen off';

  @override
  String get notificationActionDismiss => 'Turn off alert';

  @override
  String get settingsReportTitle => 'Report a problem';

  @override
  String get settingsReportSubtitle =>
      'Email us about a bug or something that felt wrong';

  @override
  String get reportSheetTitle => 'Report a problem';

  @override
  String get reportSheetHint =>
      'Your mail app will open. Describe the problem and send it yourself.';

  @override
  String get reportAttachLog => 'Attach the activity log';

  @override
  String get reportAttachLogNote =>
      'The log includes location coordinates, your saved places and settings. You can review it in the email before sending, and nothing is sent unless you send it.';

  @override
  String get reportOpenMail => 'Open mail app';

  @override
  String get reportMailSubject => '[EarLocAlert] Problem report';

  @override
  String get reportMailPrompt => 'Please describe what went wrong.';

  @override
  String get reportMailInfoHeader =>
      'The device details below help us investigate. Please keep them.';

  @override
  String reportFallbackNotice(String address) {
    return 'No mail account is set up, so the share sheet opened instead. Send it to $address.';
  }

  @override
  String get reportFailed =>
      'Could not open mail. The recipient address was copied.';

  @override
  String get settingsSectionBackup => 'Backup';

  @override
  String get settingsBackupExportTitle => 'Export places';

  @override
  String get settingsBackupExportSubtitle =>
      'Save your places as a file or send them elsewhere';

  @override
  String get settingsBackupImportTitle => 'Import places';

  @override
  String get settingsBackupImportSubtitle =>
      'Bring in places from an exported file';

  @override
  String get backupExportEmpty => 'There are no places to export';

  @override
  String get backupExportSubject => 'EarLocAlert places backup';

  @override
  String backupExportCustomSound(int count) {
    return '$count places use your own sound and were saved with the default alert sound';
  }

  @override
  String get backupImportTitle => 'Import places?';

  @override
  String backupImportBody(int count, int existing) {
    return 'Found $count places in the file. You have $existing places now. Places you already have are skipped.';
  }

  @override
  String get backupImportAdd => 'Add';

  @override
  String get backupImportReplace => 'Replace all';

  @override
  String get backupCancel => 'Cancel';

  @override
  String get backupReplaceTitle => 'Delete all current places?';

  @override
  String backupReplaceBody(int existing) {
    return 'Your $existing current places will be deleted and replaced with the ones in the file. This cannot be undone.';
  }

  @override
  String get backupReplaceConfirm => 'Replace';

  @override
  String backupImportResult(int added, int skipped) {
    return 'Imported $added places. Skipped $skipped';
  }

  @override
  String get backupImportNone => 'There are no new places to import';

  @override
  String get backupImportInvalid =>
      'This is not a places file exported from this app';

  @override
  String get backupImportNewer =>
      'This file was made by a newer version of the app. Update the app and try again';

  @override
  String get backupImportReadFailed => 'Could not read the file';

  @override
  String get proSheetTitle => 'Lifetime pass';

  @override
  String get proSheetSubtitle =>
      'Not a subscription · Stays with your account on a new phone';

  @override
  String proSheetBuy(String price) {
    return 'Lifetime pass $price';
  }

  @override
  String get proSheetRestore => 'Already purchased? Restore';

  @override
  String get proSheetColumnFree => 'Free';

  @override
  String get proSheetColumnPro => 'Pro';

  @override
  String get proRowPlaces => 'Places';

  @override
  String get proRowDirections => 'Arrival & departure alerts';

  @override
  String get proRowSchedules => 'Alert hours';

  @override
  String get proRowVibration => 'Vibration strength';

  @override
  String get proRowSound => 'Earphone sounds';

  @override
  String get proRowBackup => 'Place backup';

  @override
  String get proRowAds => 'Ads';

  @override
  String get proValueOnePlace => '1';

  @override
  String get proValueUnlimited => 'Unlimited';

  @override
  String get proValueDefaultSound => 'Default only';

  @override
  String get proValueAllSounds => 'All + your own';

  @override
  String get proValueAdsOn => 'Yes';

  @override
  String get proValueAdsOff => 'None';

  @override
  String get proUnlockAction => 'Unlock with lifetime pass';

  @override
  String get proLockedSounds => 'All sounds · Your own sounds';

  @override
  String get proLockedPlaces => 'To add more places';

  @override
  String get proLockedBackup => 'Back up · Import places';

  @override
  String get proLockedExamplePlaceHome => 'Home';

  @override
  String get proLockedExamplePlaceStation => 'Station';

  @override
  String get proCardTitle => 'Add as many places as you need';

  @override
  String get proCardSubtitle => 'All sounds · Place backup · No ads';

  @override
  String proCardUsage(int count, int limit) {
    return '$count/$limit places used';
  }

  @override
  String get proRowLifetime => 'Lifetime pass';

  @override
  String get proOwnedSubtitle => 'Every feature is unlocked';

  @override
  String get proDeviceLimitReached => 'You have reached the device limit';

  @override
  String get proPriceLoading => 'Checking price…';

  @override
  String get proProductUnavailable =>
      'Purchase is unavailable right now. Please try again later';

  @override
  String get proPurchasePending =>
      'It will unlock once the payment is confirmed';

  @override
  String get proPurchaseDone => 'Lifetime pass unlocked';

  @override
  String get proPurchaseFailed => 'The payment could not be completed';

  @override
  String get proRestoreNone => 'No purchase to restore';

  @override
  String get proRestoreDone => 'Purchase restored';

  @override
  String get proChipFree => 'FREE';

  @override
  String get proChipPro => 'PRO';

  @override
  String get proInfoTitle => 'Pass details';

  @override
  String get proInfoStatus => 'Status';

  @override
  String get proInfoStatusActive => 'Active';

  @override
  String get proInfoSource => 'Unlocked by';

  @override
  String get proSourcePurchase => 'Purchase';

  @override
  String get proInfoPurchasedAt => 'Purchased on';

  @override
  String get proInfoOrderId => 'Order number';

  @override
  String get proInfoUnknown => 'Checking';

  @override
  String get proInfoNotePurchase =>
      'Purchased with this device\'s Google Play account. On a new phone, the same account can bring it back with \"Restore purchase\".';

  @override
  String get proInfoRestore => 'Restore purchase';

  @override
  String get proSheetRedeem => 'Redeem promo code';

  @override
  String get homeStatusSheetTitle => 'Current status';

  @override
  String get homeStatusWatchingDescription =>
      'You\'ll be alerted when you arrive at or leave a place that\'s turned on';

  @override
  String get homeStatusOffDescription =>
      'Places are on but monitoring has stopped. Check location permission';

  @override
  String get homeStatusCheckingDescription => 'Checking monitoring status';

  @override
  String get homeStatusIdleDescription =>
      'No places are on. Turn one on to start monitoring';

  @override
  String get homeAudioHeadphonesDescription =>
      'Sound and vibration come through your earphones';

  @override
  String get homeAudioVibrationOnlyDescription =>
      'No earphones connected, so alerts are vibration only';

  @override
  String get homeStatusFixButton => 'Check permissions';
}
