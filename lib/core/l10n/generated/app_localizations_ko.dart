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

  @override
  String get permissionContinue => '계속';

  @override
  String get permissionLocalOnlyFootnote => '위치 정보는 기기에만 저장되며 어디에도 전송되지 않습니다.';

  @override
  String get permissionLocationTitle => '위치 권한이 필요합니다';

  @override
  String get permissionLocationBody =>
      '알림을 걸어둘 장소를 지도에서 고르고, 지금 어디쯤인지 표시하기 위해 사용합니다.';

  @override
  String get permissionBackgroundTitle => '항상 허용이 필요합니다';

  @override
  String get permissionBackgroundBody =>
      '앱을 열어두지 않아도 도착과 출발을 알려드리려면 백그라운드에서 위치를 확인해야 합니다.\n\n이 권한이 없으면 화면을 계속 보고 있어야 해서, 알림 자체가 의미를 잃습니다.';

  @override
  String get permissionBackgroundActionAndroid => '설정에서 항상 허용';

  @override
  String get permissionBackgroundFootnoteAndroid =>
      '설정 화면에서 위치 권한을 \"항상 허용\"으로 바꿔주세요.\n위치 정보는 기기에만 저장되며 어디에도 전송되지 않습니다.';

  @override
  String get permissionNotificationTitle => '알림 권한이 필요합니다';

  @override
  String get permissionNotificationBody => '도착하거나 떠날 때 알려드리기 위해 사용합니다.';

  @override
  String get permissionReliabilityTitle => '알림을 놓치지 않으려면';

  @override
  String get permissionReliabilityBody =>
      '휴대폰이 절전에 들어가거나 다른 앱을 보고 있으면, 도착 알림이 늦게 오거나 작은 알림으로만 지나갑니다.\n\n다음 세 가지를 켜면 화면을 덮는 알림이 해제할 때까지 계속됩니다.\n\n• 배터리 사용량 최적화 제외: 절전 중에도 제때 알립니다\n• 다른 앱 위에 표시: 영상을 보는 중에도 알림 화면이 뜹니다\n• 전체 화면 알림: 화면이 꺼져 있어도 깨웁니다';

  @override
  String get permissionReliabilityAction => '세 가지 모두 켜기';

  @override
  String get permissionReliabilityFootnote =>
      '설정 화면이 차례로 열립니다. 건너뛰면 알림 화면이 저절로 뜨지 않아, 진동을 끄려면 알림을 눌러 앱을 열어야 합니다.';

  @override
  String get permissionOpenSettingsTitle => '설정에서 직접 바꿔주세요';

  @override
  String get permissionOpenSettingsBody =>
      '앱 안에서는 다시 물을 수 없는 권한이에요. 설정을 열어 아래처럼 바꿔주세요.';

  @override
  String get permissionOpenSettingsAction => '설정 열기';

  @override
  String get permissionSettingsLocationRow => '위치 → 앱을 사용하는 동안 또는 항상';

  @override
  String get permissionSettingsBackgroundRowIos => '위치 → 항상';

  @override
  String get permissionSettingsBackgroundRowAndroid => '위치 → 항상 허용';

  @override
  String get permissionSettingsNotificationRow => '알림 → 알림 허용';

  @override
  String get permissionSettingsReturnHintIos =>
      '바꾼 뒤 화면 왼쪽 위의 ◀ 앱 이름을 누르면 앱으로 돌아와요. 위치 권한을 바꾸면 앱이 다시 시작될 수 있어요.';

  @override
  String get permissionSettingsReturnHintAndroid => '바꾼 뒤 뒤로 가기로 앱에 돌아오세요.';

  @override
  String get permissionDoneTitle => '준비되었습니다';

  @override
  String get permissionDoneBody => '이제 장소를 등록하면 도착과 출발을 알려드립니다.';

  @override
  String get permissionDoneAction => '시작하기';

  @override
  String get onboardingSkip => '나중에 하기';

  @override
  String get onboardingErrorTitle => '권한 상태를 확인하지 못했습니다';

  @override
  String get onboardingErrorHint => '잠시 후 다시 시도해주세요.';

  @override
  String get onboardingRetry => '다시 시도';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSectionAlert => '알림';

  @override
  String get settingsVibrationTitle => '진동 세기';

  @override
  String get settingsVibrationSubtitle => '이어폰이 없을 때는 진동만으로 알립니다';

  @override
  String get settingsVolumeTitle => '알림음 크기';

  @override
  String get settingsVolumeSubtitle => '이어폰으로 들릴 소리 크기';

  @override
  String get settingsSectionReach => '알림 도달 권한';

  @override
  String get settingsSectionGeneral => '일반';

  @override
  String get settingsSectionTroubleshoot => '문제 해결';

  @override
  String get settingsDiagnosticsTitle => '동작 기록';

  @override
  String get settingsDiagnosticsSubtitle => '알림이 언제 왜 울렸는지 기록을 보고 내보냅니다';

  @override
  String get settingsPermissionGranted => '허용됨';

  @override
  String get settingsPermNotifyTitle => '알림 표시';

  @override
  String get settingsPermNotifyDesc => '없으면 도착해도 알림이 뜨지 않습니다';

  @override
  String get settingsPermBatteryTitle => '배터리 최적화 제외';

  @override
  String get settingsPermBatteryDesc => '없으면 절전 중 알림이 늦거나 오지 않습니다';

  @override
  String get settingsPermOverlayTitle => '다른 앱 위에 표시';

  @override
  String get settingsPermOverlayDesc => '없으면 앱 사용 중에 알림 화면이 뜨지 않습니다';

  @override
  String get settingsPermFullScreenTitle => '전체 화면 알림';

  @override
  String get settingsPermFullScreenDesc => '없으면 화면이 꺼져 있을 때 알림 화면이 뜨지 않습니다';

  @override
  String get diagnosticsTitle => '동작 기록';

  @override
  String get diagnosticsRefresh => '새로고침';

  @override
  String get diagnosticsClear => '지우기';

  @override
  String get diagnosticsCancel => '취소';

  @override
  String get diagnosticsExport => '내보내기';

  @override
  String get diagnosticsExportSubject => '이어폰위치알림 기록';

  @override
  String get diagnosticsCopied => '클립보드에 복사했습니다';

  @override
  String get diagnosticsClearTitle => '기록을 지울까요?';

  @override
  String get diagnosticsClearBody => '지운 기록은 되돌릴 수 없습니다.';

  @override
  String diagnosticsHeader(int lineCount, String size, String maxSize) {
    return '$lineCount건 · $size / 최대 $maxSize\n기기 안에만 저장되며 전송되지 않습니다. 가득 차면 오래된 것부터 지워집니다';
  }

  @override
  String get diagnosticsReadFailed => '기록을 읽지 못했습니다.';

  @override
  String get diagnosticsEmpty => '아직 기록이 없습니다.\n앱을 다시 켜거나 감시가 시작되면 쌓입니다.';

  @override
  String get diagnosticsCopyAll => '전체 복사';

  @override
  String get diagnosticsAppState => '앱 상태';

  @override
  String get diagnosticsAppStateHint => '권한·장소·설정·기기 상태입니다. 내보내기에 함께 담깁니다';

  @override
  String get diagnosticsSearchHint => '태그·장소·내용 검색';

  @override
  String diagnosticsProblemsOnly(int count) {
    return '문제만 $count';
  }

  @override
  String get diagnosticsAllSources => '전체';

  @override
  String get diagnosticsSourceApp => '앱';

  @override
  String get diagnosticsSourceBackground => '백그라운드';

  @override
  String get diagnosticsSourceNative => '네이티브';

  @override
  String get diagnosticsSourceIos => 'iOS';

  @override
  String diagnosticsShownCount(int shown) {
    return '$shown건 표시 중';
  }

  @override
  String diagnosticsPeriod(String from, String to) {
    return '기간 $from ~ $to';
  }

  @override
  String get diagnosticsNoMatch => '조건에 맞는 기록이 없습니다.';

  @override
  String get routeDeletedSound => '삭제된 음원 (기본음으로 알림)';

  @override
  String get notificationChannelName => '도착·출발 알림';

  @override
  String get notificationChannelDescription => '등록한 장소에 도착하거나 떠날 때 알립니다';

  @override
  String get notificationArrived => '도착했습니다';

  @override
  String get notificationLeft => '떠났습니다';

  @override
  String get alertScreenLeft => '떠났습니다';

  @override
  String get alertScreenArrived => '도착했습니다';

  @override
  String alertScreenTimeAm(String hour, String minute) {
    return '오전 $hour:$minute';
  }

  @override
  String alertScreenTimePm(String hour, String minute) {
    return '오후 $hour:$minute';
  }

  @override
  String get alertScreenRouteHeadphones => '이어폰으로 알림 중';

  @override
  String get alertScreenRouteSoundFailed => '소리를 재생하지 못해 진동으로 알림 중';

  @override
  String get alertScreenRouteVibrationOnly => '진동으로만 알림 중';

  @override
  String get alertScreenDismiss => '알림 끄기';

  @override
  String get alertAlarmOpenApp => '앱 열기';

  @override
  String alertScreenRadius(int meters) {
    return '반경 ${meters}m';
  }

  @override
  String get alertNotificationChannelName => '알림 진행 중';

  @override
  String get alertNotificationChannelDescription =>
      '알림 화면을 벗어났을 때 다시 돌아오는 알림입니다';

  @override
  String get alertDismissedTitle => '알림을 껐습니다';

  @override
  String get volumeTitle => '알림음 크기';

  @override
  String get volumeDescription =>
      '알림이 울릴 때 시스템 볼륨이 이 수준보다 낮으면 여기까지 올렸다가, 끄면 원래대로 되돌립니다.';

  @override
  String get volumePreviewStop => '미리듣기 멈추기';

  @override
  String get volumePreviewNoHeadphones => '이어폰이 연결되어 있지 않아 미리듣기를 할 수 없습니다.';

  @override
  String get volumePreviewFailed => '재생에 실패했습니다.';

  @override
  String get vibrationTitle => '진동 세기';

  @override
  String get vibrationDescription =>
      '이어폰이 연결되지 않았을 때는 진동만으로 알립니다. 고르면 그 세기로 한 번 울려 확인할 수 있습니다.';

  @override
  String get vibrationWeak => '약하게';

  @override
  String get vibrationNormal => '보통';

  @override
  String get vibrationStrong => '강하게';

  @override
  String get vibrationWeakHint => '조용한 곳에서 주변에 들리지 않게';

  @override
  String get vibrationNormalHint => '기본값';

  @override
  String get vibrationStrongHint => '주머니나 가방 속에서도 느껴지게';

  @override
  String get soundPreview => '미리듣기';

  @override
  String get soundCancel => '취소';

  @override
  String get soundDelete => '삭제';

  @override
  String get soundDone => '완료';

  @override
  String get soundPickerTitle => '알림음';

  @override
  String get soundPickerPresetHeader => '기본 알림음';

  @override
  String soundPickerCustomHeader(int count, int max) {
    return '내 음원  $count/$max';
  }

  @override
  String get soundPickerCustomEmpty => '기기에 있는 음원 파일을 등록해 쓸 수 있습니다.';

  @override
  String get soundPickerAdd => '음원 추가';

  @override
  String get soundPickerChecking => '확인 중…';

  @override
  String get soundPickerHeadphoneNotice =>
      '이어폰을 연결하면 들어볼 수 있습니다. 알림음은 이어폰이 연결됐을 때만 재생됩니다.';

  @override
  String get soundPreviewFailed => '재생할 수 없는 음원입니다';

  @override
  String get soundSaveFailed => '음원을 저장하지 못했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get soundDeleteTitle => '음원을 삭제할까요?';

  @override
  String soundDeleteBody(String name) {
    return '$name\n\n이 음원을 쓰던 장소는 기본음으로 알립니다.';
  }

  @override
  String soundDurationMinutesSeconds(int minutes, int seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String soundImportLimitReached(int max) {
    return '음원은 최대 $max개까지 등록할 수 있습니다. 쓰지 않는 음원을 지우고 다시 시도해주세요.';
  }

  @override
  String soundImportNoExtension(String allowed) {
    return '확장자가 없는 파일입니다. $allowed 형식만 쓸 수 있습니다.';
  }

  @override
  String soundImportUnsupported(String extension, String allowed) {
    return '$extension 형식은 쓸 수 없습니다. $allowed 만 가능합니다.';
  }

  @override
  String soundImportTooLarge(String size, String max) {
    return '파일이 너무 큽니다 ($size / 최대 $max).';
  }

  @override
  String soundImportTooLong(String duration, String max) {
    return '너무 깁니다 ($duration / 최대 $max). 알림음은 반복 재생되므로 짧아도 됩니다.';
  }

  @override
  String get soundImportNotPlayable => '재생할 수 없는 파일입니다. 다른 파일을 골라주세요.';

  @override
  String get soundPresetDefault => '기본음';

  @override
  String get soundPresetBell => '종소리';

  @override
  String get soundPresetElectronic => '전자음';

  @override
  String get soundPresetSiren => '사이렌';

  @override
  String get soundPresetChime => '차임';

  @override
  String get placeSearchUnnamed => '이름 없는 장소';

  @override
  String get placePickerTitle => '지도에서 선택';

  @override
  String get placeMyLocation => '내 위치';

  @override
  String get placeSearchHint => '장소·주소 검색';

  @override
  String get placeSearchUnavailable => '검색을 사용할 수 없습니다. 지도를 움직여 위치를 맞춰주세요';

  @override
  String get placePickerPinHint => '지도를 움직여 핀을 맞추세요';

  @override
  String get placePickerConfirm => '이 위치로 선택';

  @override
  String get placeDirectionEnter => '도착 알림';

  @override
  String get placeDirectionExit => '출발 알림';

  @override
  String get placeDirectionBoth => '도착·출발';

  @override
  String placeRadiusInfo(String direction, int meters) {
    return '$direction · 반경 ${meters}m';
  }

  @override
  String placeDeleted(String name) {
    return '\'$name\' 삭제됨';
  }

  @override
  String get placeUndo => '되돌리기';

  @override
  String get placeSwipeDeleteLabel => '삭제';

  @override
  String get placeFormDelete => '이 장소 삭제';

  @override
  String get placeFormDeleteTitle => '이 장소를 삭제할까요?';

  @override
  String placeFormDeleteBody(String name) {
    return '\'$name\' 장소가 목록에서 사라집니다. 삭제한 직후에는 되돌릴 수 있습니다.';
  }

  @override
  String get placeDeleteCancel => '취소';

  @override
  String get placeFormLeaveTitle => '저장하지 않고 나갈까요?';

  @override
  String get placeFormLeaveBody => '지금까지 바꾼 내용은 사라집니다.';

  @override
  String get placeFormKeepEditing => '계속 편집';

  @override
  String get placeFormLeave => '나가기';

  @override
  String get placeFormTitleNew => '장소 등록';

  @override
  String get placeFormTitleEdit => '장소 편집';

  @override
  String get placeFormNameLabel => '이름';

  @override
  String get placeFormNameHint => '예: 내릴 정류장, 약속 장소';

  @override
  String get placeFormLocationLabel => '위치';

  @override
  String get placeFormPickOnMap => '지도에서 선택';

  @override
  String get placeFormRepickOnMap => '지도에서 다시 선택';

  @override
  String get placeFormNoLocation => '아직 위치를 고르지 않았습니다';

  @override
  String placeFormCoordinates(String value) {
    return '좌표  $value';
  }

  @override
  String get placeFormCoordinatesManual => '좌표 직접 입력';

  @override
  String get placeFormLatitude => '위도';

  @override
  String get placeFormLongitude => '경도';

  @override
  String get placeFormRadiusLabel => '알림 반경';

  @override
  String placeFormRadiusValue(int meters) {
    return '${meters}m';
  }

  @override
  String get placeFormTimingLabel => '알림 시점';

  @override
  String get placeFormTimingEnter => '도착';

  @override
  String get placeFormTimingExit => '출발';

  @override
  String get placeFormTimingBoth => '둘 다';

  @override
  String get placeFormSoundTitle => '이어폰 소리 알림';

  @override
  String get placeFormSoundDescription =>
      '이어폰(줄·블루투스)이 연결된 경우에만 소리가 납니다.\n스피커로는 절대 소리가 나지 않습니다.';

  @override
  String get placeFormSoundLabel => '알림음';

  @override
  String get placeFormCustomSound => '내 음원';

  @override
  String get placeFormSubmitNew => '등록';

  @override
  String get placeFormSubmitSave => '저장';

  @override
  String get placeErrorEmptyName => '이름을 입력해주세요';

  @override
  String placeErrorRadius(int min, int max) {
    return '반경은 ${min}m ~ ${max}m 사이여야 합니다';
  }

  @override
  String get placeErrorCoordinates => '위치 좌표가 올바르지 않습니다';

  @override
  String placeErrorLimit(int max) {
    return '장소는 최대 $max개까지 등록할 수 있습니다';
  }

  @override
  String get placeErrorEmptyWindow => '시간대의 시작과 종료가 같습니다. 하루 종일 알리려면 시간대를 지우세요';

  @override
  String get placeErrorNoDays => '시간대에 요일을 하나 이상 골라주세요';

  @override
  String get placeEmptyTitle => '첫 장소를 등록해주세요';

  @override
  String get placeEmptyAction => '장소 등록';

  @override
  String get placeHomeLocationUnavailable => '현재 위치를 확인할 수 없습니다. 위치 권한을 확인해주세요';

  @override
  String get placeLocationSlow => '현재 위치를 찾는 중 시간이 걸리고 있어요. 잠시 후 다시 눌러주세요';

  @override
  String get placeHomeStatusWatching => '감시 중';

  @override
  String get placeHomeStatusOff => '감시 꺼짐';

  @override
  String get placeHomeStatusChecking => '확인 중';

  @override
  String get placeHomeStatusIdle => '감시 대기';

  @override
  String get placeHomeAudioHeadphones => '이어폰';

  @override
  String get placeHomeAudioVibrationOnly => '진동만';

  @override
  String get placeHomeWeakTitle => '알림이 안 울릴 수 있어요';

  @override
  String get placeHomeWeakChip => '알림 약함';

  @override
  String get placeHomeWeakFixButton => '켜기';

  @override
  String get placeHomeWeakPowerSaving => '절전 중이거나 다른 앱을 쓰는 동안 알림이 약해집니다';

  @override
  String placeHomeWeakMissing(String items) {
    return '$items 꺼짐 · 눌러서 켜기';
  }

  @override
  String get placeHomeAddPlace => '장소 추가';

  @override
  String get placeHomeLoadFailed => '장소를 불러오지 못했습니다';

  @override
  String get placeHomeSettings => '설정';

  @override
  String get scheduleTitle => '알림 시간대';

  @override
  String get scheduleAlways => '항상 알림';

  @override
  String get scheduleAlwaysHint => '항상 알림. 시간대를 더하면 그 시간에만 울립니다';

  @override
  String get scheduleAdd => '시간대 추가';

  @override
  String get scheduleRemove => '이 시간대 삭제';

  @override
  String get scheduleSheetAddTitle => '시간대 추가';

  @override
  String get scheduleSheetEditTitle => '시간대 편집';

  @override
  String get scheduleDaysLabel => '요일';

  @override
  String get scheduleEveryday => '매일';

  @override
  String get scheduleWeekdays => '평일';

  @override
  String get scheduleWeekends => '주말';

  @override
  String get scheduleDayMon => '월';

  @override
  String get scheduleDayTue => '화';

  @override
  String get scheduleDayWed => '수';

  @override
  String get scheduleDayThu => '목';

  @override
  String get scheduleDayFri => '금';

  @override
  String get scheduleDaySat => '토';

  @override
  String get scheduleDaySun => '일';

  @override
  String get scheduleStart => '시작';

  @override
  String get scheduleEnd => '종료';

  @override
  String scheduleCrossesMidnight(String window) {
    return '종료가 시작보다 이르므로 자정을 넘긴 것으로 봅니다 ($window)';
  }

  @override
  String get scheduleSameStartEnd =>
      '시작과 종료가 같습니다. 하루 종일 알리려면 시간대를 만들지 않으면 됩니다.';

  @override
  String get scheduleSave => '저장';

  @override
  String get scheduleAddButton => '추가';

  @override
  String get settingsWatchTitle => '워치로 알림 받기';

  @override
  String get settingsWatchSubtitle => '스마트워치에서도 도착 알림을 받는 방법';

  @override
  String get watchGuideIntro =>
      '스마트워치를 차고 있다면 워치에서도 알림을 받을 수 있어요. 워치 쪽 설정을 한 번만 켜 주세요.';

  @override
  String get watchGuideAndroidStep1 => '폰에서 Galaxy Wearable 같은 워치 앱을 엽니다';

  @override
  String get watchGuideAndroidStep2 => '워치 설정 → 알림 → 앱 알림으로 들어갑니다';

  @override
  String watchGuideAndroidStep3(String appName) {
    return '목록에서 \"$appName\"을 켭니다';
  }

  @override
  String get watchGuideIosStep1 => 'iPhone 에서 Watch 앱을 엽니다';

  @override
  String get watchGuideIosStep2 => '알림으로 들어갑니다';

  @override
  String watchGuideIosStep3(String appName) {
    return '\"$appName\"이 보이면 켭니다. iPhone 이 잠겨 있을 때 워치로 알림이 갑니다';
  }

  @override
  String get watchGuideNote => '워치가 울리는 방식은 워치 설정에 따라 다를 수 있어요.';

  @override
  String get watchGuideConfirm => '알겠어요';

  @override
  String get settingsThemeTitle => '화면 모드';

  @override
  String get themeSystem => '기기 설정 따르기';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get themeSheetHint => '알림이 울리는 화면은 눈부시지 않게 항상 어둡게 보여요.';

  @override
  String get themeChanged => '화면 모드를 바꿨어요';

  @override
  String get themeUndo => '되돌리기';

  @override
  String get placeFormSaveFailed => '저장하지 못했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get scheduleCancel => '취소';

  @override
  String scheduleWindow(String days, String start, String end) {
    return '$days $start ~ $end';
  }

  @override
  String scheduleWindowNextDay(String days, String start, String end) {
    return '$days $start ~ $end (익일)';
  }

  @override
  String scheduleTimeRange(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String scheduleTimeRangeNextDay(String start, String end) {
    return '$start ~ $end (익일)';
  }

  @override
  String scheduleMore(String first, int count) {
    return '$first 외 $count개';
  }

  @override
  String get appUpdateReady => '새 버전을 받았어요';

  @override
  String get appUpdateRestart => '다시 시작';

  @override
  String get settingsVersionTitle => '앱 버전';

  @override
  String get settingsVersionCheck => '업데이트 확인';

  @override
  String get appUpdateNone => '지금 받을 수 있는 업데이트가 없어요';

  @override
  String get settingsSectionAbout => '정보';

  @override
  String get settingsTermsTitle => '이용약관';

  @override
  String get settingsPrivacyTitle => '개인정보처리방침';

  @override
  String get settingsLicensesTitle => '오픈소스 라이선스';

  @override
  String get settingsAdPrivacyTitle => '광고 개인정보 설정';

  @override
  String get settingsAdPrivacySubtitle => '광고 동의 선택을 다시 확인하거나 바꿉니다';

  @override
  String get settingsOpenLinkFailed => '링크를 열 수 없어요. 브라우저가 설치되어 있는지 확인해 주세요';

  @override
  String get settingsLockAlarmTitle => '잠금화면 알람';

  @override
  String get settingsLockAlarmOn => '화면이 꺼져 있으면 잠금 화면 전체에 알람을 띄워요';

  @override
  String get settingsLockAlarmNotDetermined =>
      '허용하면 화면이 꺼져 있을 때 잠금 화면 전체에 알람을 띄워요';

  @override
  String get settingsLockAlarmDenied =>
      '꺼져 있어요. 설정에서 알람을 허용하면 잠금 화면 전체에 알람을 띄워요';

  @override
  String get settingsLockAlarmNeedsNewerOs =>
      '화면 전체를 덮는 알람은 iOS 26 이상에서 쓸 수 있어요. 지금은 알림과 진동으로 알려 드려요.';

  @override
  String get settingsLockAlarmAllow => '허용';

  @override
  String get settingsLockAlarmOpenSettings => '설정 열기';

  @override
  String get settingsVibrationTestTitle => '진동 시험';

  @override
  String get vibrationCheckTitle => '화면이 꺼져 있어도\n진동이 오는지 확인할게요';

  @override
  String get vibrationCheckDescription =>
      '이어폰이 없을 땐 진동이 유일한 알림이에요. 아이폰 설정에 따라 진동이 막혀 있을 수 있어요.';

  @override
  String get vibrationCheckItemNotifications => '알림 허용';

  @override
  String get vibrationCheckItemLockScreen => '잠금 화면에 표시';

  @override
  String get vibrationCheckItemSound => '알림 사운드';

  @override
  String get vibrationCheckItemHaptics => '햅틱 · 진동';

  @override
  String get vibrationCheckStatusOn => '켜짐';

  @override
  String get vibrationCheckStatusOff => '꺼짐';

  @override
  String get vibrationCheckStatusByTest => '시험으로 확인';

  @override
  String get vibrationCheckBlockedHint =>
      '꺼진 항목을 먼저 켜 주세요. 알림 사운드가 꺼지면 진동도 함께 빠져요. 소리는 나지 않는 알림음이에요.';

  @override
  String get vibrationCheckOpenNotificationSettings => '알림 설정 열기';

  @override
  String get vibrationCheckSendTest => '시험 알림 보내기';

  @override
  String get vibrationCheckLater => '나중에';

  @override
  String get vibrationCheckScheduleFailed => '시험 알림을 보내지 못했어요. 다시 눌러 주세요.';

  @override
  String get vibrationCheckNotificationTitle => '진동 점검';

  @override
  String get vibrationCheckNotificationBody => '진동이 왔나요? 앱으로 돌아와 알려 주세요';

  @override
  String get vibrationCheckWaitingTitle => '지금 화면을 잠가 주세요';

  @override
  String vibrationCheckWaitingBody(int seconds) {
    return '$seconds초 뒤 도착 알림과 똑같은 알림이 와요. 진동이 오는지 느껴 보세요.';
  }

  @override
  String get vibrationCheckCancel => '취소';

  @override
  String get vibrationCheckNotLockedTitle => '화면을 잠그지 않았어요';

  @override
  String get vibrationCheckNotLockedBody =>
      '앱이 켜져 있으면 실제 도착과 달라 시험이 안 돼요. 버튼을 누른 뒤 바로 화면을 잠가 주세요.';

  @override
  String get vibrationCheckTryAgain => '다시 시험하기';

  @override
  String get vibrationCheckAskTitle => '방금 알림이 올 때\n진동을 느꼈나요?';

  @override
  String get vibrationCheckAskBody => '소리는 나지 않는 게 맞아요. 떨림만 확인해 주세요.';

  @override
  String get vibrationCheckAnswerFelt => '느꼈어요';

  @override
  String get vibrationCheckAnswerNotFelt => '못 느꼈어요';

  @override
  String get vibrationCheckAnswerNoNotification => '알림이 안 왔어요';

  @override
  String get vibrationCheckGuideHapticsEyebrow => '가장 흔한 원인';

  @override
  String get vibrationCheckGuideHapticsTitle => '햅틱을 \'항상 재생\'으로';

  @override
  String get vibrationCheckGuideAccessibilityEyebrow => '기기 전체 진동 스위치';

  @override
  String get vibrationCheckGuideAccessibilityTitle => '진동 켜기';

  @override
  String get vibrationCheckGuideAccessibilityHint =>
      '이 스위치가 꺼져 있으면 전화와 알림 진동이 전부 막혀요.';

  @override
  String get vibrationCheckGuideFocusEyebrow => '마지막 확인';

  @override
  String get vibrationCheckGuideFocusTitle => '집중 모드에서 이 앱 허용';

  @override
  String get vibrationCheckGuideFocusHint => '집중 모드를 쓰지 않는다면 넘어가도 돼요.';

  @override
  String get vibrationCheckGuideOpenSettingsHint =>
      '\'설정 열기\'는 이 앱 설정 페이지를 열어요. 왼쪽 위 뒤로 버튼으로 설정 첫 화면에 가 주세요.';

  @override
  String get vibrationCheckOpenSettings => '설정 열기';

  @override
  String get vibrationCheckGuideChanged => '바꿨어요';

  @override
  String get vibrationCheckGuideStillNot => '그래도 안 되면';

  @override
  String get vibrationCheckSuccessTitle => '준비됐어요';

  @override
  String get vibrationCheckSuccessBody => '이어폰이 없어도 도착하면\n화면이 꺼진 채로 진동이 와요.';

  @override
  String get vibrationCheckDone => '확인';

  @override
  String get vibrationCheckStillTitle => '다른 앱 알림은 떨리나요?';

  @override
  String get vibrationCheckStillBody =>
      '메시지가 올 때도 안 떨리면 기기 쪽 설정이에요. 벨소리의 햅틱 패턴이 \'없음\'으로 되어 있지 않은지 확인해 보세요.';

  @override
  String get vibrationCheckClose => '닫기';

  @override
  String get iosSettingsRoot => '설정';

  @override
  String get iosSettingsSoundsAndHaptics => '사운드 및 햅틱';

  @override
  String get iosSettingsHaptics => '햅틱';

  @override
  String get iosSettingsHapticsAlways => '항상 재생';

  @override
  String get iosSettingsHapticsSilentOnly => '무음 모드에서 재생';

  @override
  String get iosSettingsHapticsNotInSilent => '무음 모드에서 재생 안 함';

  @override
  String get iosSettingsHapticsNever => '재생 안 함';

  @override
  String get iosSettingsAccessibility => '손쉬운 사용';

  @override
  String get iosSettingsTouch => '터치';

  @override
  String get iosSettingsTapToWake => '탭하여 깨우기';

  @override
  String get iosSettingsShakeToUndo => '흔들어서 실행 취소';

  @override
  String get iosSettingsVibration => '진동';

  @override
  String get iosSettingsFocus => '집중 모드';

  @override
  String get iosSettingsFocusMode => '사용 중인 모드';

  @override
  String get iosSettingsFocusAllowApp => '허용된 알림 › 앱 추가';

  @override
  String get iosSettingsRingtone => '벨소리';

  @override
  String get iosSettingsRingtoneHapticsNotNone => '햅틱 ≠ 없음';

  @override
  String get settingsVibrationCheckTitle => '알림이 안 울린다면';

  @override
  String get settingsVibrationCheckSubtitle => '진동 점검과 아이폰 설정 안내';

  @override
  String get onboardingVibrationCardTitle => '진동이 느껴지는지 확인해 보세요';

  @override
  String get onboardingVibrationCardBody =>
      'iPhone 진동 설정이 꺼져 있으면 도착해도 아무 느낌이 없어요.';

  @override
  String get homeGapNotifications => '알림 허용';

  @override
  String get homeGapLockScreen => '잠금 화면 알림';

  @override
  String get homeGapVibration => '진동';

  @override
  String get settingsLockScreenNotifyTitle => '잠금 화면에 표시';

  @override
  String get settingsLockScreenNotifyDesc =>
      '꺼져 있으면 화면이 꺼진 채 도착했을 때 아무것도 보이지 않아요';

  @override
  String get notificationActionDismiss => '알림 끄기';

  @override
  String get settingsReportTitle => '문제 신고';

  @override
  String get settingsReportSubtitle => '불편한 점이나 오류를 메일로 보냅니다';

  @override
  String get reportSheetTitle => '문제 신고';

  @override
  String get reportSheetHint => '메일 앱이 열립니다. 내용을 적고 직접 보내 주세요.';

  @override
  String get reportAttachLog => '동작 기록 함께 보내기';

  @override
  String get reportAttachLogNote =>
      '위치 좌표·등록 장소·설정이 담긴 기록이 첨부됩니다. 보내기 전에 메일에서 확인할 수 있고, 직접 보낼 때만 전송됩니다.';

  @override
  String get reportOpenMail => '메일 앱 열기';

  @override
  String get reportMailSubject => '[이어폰위치알림] 문제 신고';

  @override
  String get reportMailPrompt => '어떤 문제가 있었는지 적어 주세요.';

  @override
  String get reportMailInfoHeader => '아래는 확인에 필요한 기기 정보입니다. 지우지 말아 주세요.';

  @override
  String reportFallbackNotice(String address) {
    return '메일 계정이 없어 공유 화면으로 열었습니다. 받는 사람은 $address 입니다.';
  }

  @override
  String get reportFailed => '메일을 열지 못했습니다. 받는 사람 주소를 복사했습니다.';

  @override
  String get settingsSectionBackup => '백업';

  @override
  String get settingsBackupExportTitle => '장소 내보내기';

  @override
  String get settingsBackupExportSubtitle => '등록한 장소를 파일로 저장하거나 다른 곳으로 보냅니다';

  @override
  String get settingsBackupImportTitle => '장소 불러오기';

  @override
  String get settingsBackupImportSubtitle => '내보낸 파일에서 장소를 가져옵니다';

  @override
  String get backupExportEmpty => '내보낼 장소가 없습니다';

  @override
  String get backupExportSubject => '이어폰위치알림 장소 백업';

  @override
  String backupExportCustomSound(int count) {
    return '내 음원을 쓰는 장소 $count곳은 기본 알림음으로 담았습니다';
  }

  @override
  String get backupImportTitle => '장소를 불러올까요?';

  @override
  String backupImportBody(int count, int existing) {
    return '파일에서 장소 $count곳을 찾았습니다. 지금 등록된 장소는 $existing곳입니다. 이미 있는 장소는 건너뜁니다.';
  }

  @override
  String get backupImportAdd => '추가하기';

  @override
  String get backupImportReplace => '모두 바꾸기';

  @override
  String get backupCancel => '취소';

  @override
  String get backupReplaceTitle => '기존 장소를 모두 지울까요?';

  @override
  String backupReplaceBody(int existing) {
    return '지금 등록된 장소 $existing곳이 지워지고 파일의 장소로 바뀝니다. 되돌릴 수 없습니다.';
  }

  @override
  String get backupReplaceConfirm => '바꾸기';

  @override
  String backupImportResult(int added, int skipped) {
    return '장소 $added곳을 불러왔습니다. 건너뜀 $skipped곳';
  }

  @override
  String get backupImportNone => '불러올 새 장소가 없습니다';

  @override
  String get backupImportInvalid => '이 앱에서 내보낸 장소 파일이 아닙니다';

  @override
  String get backupImportNewer => '더 새로운 버전의 앱에서 만든 파일입니다. 앱을 업데이트한 뒤 다시 불러오세요';

  @override
  String get backupImportReadFailed => '파일을 읽지 못했습니다';

  @override
  String get proSheetTitle => '평생 이용권';

  @override
  String get proSheetSubtitle => '구독 아님 · 기기 바꿔도 같은 계정이면 유지';

  @override
  String proSheetBuy(String price) {
    return '평생 이용권 $price';
  }

  @override
  String get proSheetRestore => '이미 구매했나요? 복원하기';

  @override
  String get proSheetColumnFree => '무료';

  @override
  String get proSheetColumnPro => '프로';

  @override
  String get proRowPlaces => '장소';

  @override
  String get proRowDirections => '도착·출발 알림';

  @override
  String get proRowSchedules => '알림 시간대';

  @override
  String get proRowVibration => '진동 세기';

  @override
  String get proRowSound => '이어폰 알림음';

  @override
  String get proRowBackup => '장소 백업';

  @override
  String get proRowAds => '광고';

  @override
  String get proValueOnePlace => '1개';

  @override
  String get proValueUnlimited => '제한 없음';

  @override
  String get proValueDefaultSound => '기본 1개';

  @override
  String get proValueAllSounds => '전체 + 내 음원';

  @override
  String get proValueAdsOn => '있음';

  @override
  String get proValueAdsOff => '없음';

  @override
  String get proUnlockAction => '평생 이용권으로 열기';

  @override
  String get proLockedSounds => '알림음 전체 · 내 음원';

  @override
  String get proLockedPlaces => '장소를 더 등록하려면';

  @override
  String get proLockedBackup => '장소 백업 · 가져오기';

  @override
  String get proLockedExamplePlaceHome => '집';

  @override
  String get proLockedExamplePlaceStation => '역';

  @override
  String get proCardTitle => '장소를 제한 없이 등록하세요';

  @override
  String get proCardSubtitle => '알림음 전체 · 장소 백업 · 광고 없음';

  @override
  String proCardUsage(int count, int limit) {
    return '장소 $count/$limit 사용 중';
  }

  @override
  String get proRowLifetime => '평생 이용권';

  @override
  String get proOwnedSubtitle => '모든 기능이 열려 있어요';

  @override
  String get proDeviceLimitReached => '기기 한도에 도달했어요';

  @override
  String get proPriceLoading => '가격 확인 중…';

  @override
  String get proProductUnavailable => '지금은 구매할 수 없어요. 잠시 뒤 다시 시도해 주세요';

  @override
  String get proPurchasePending => '결제가 확인되면 열려요';

  @override
  String get proPurchaseDone => '평생 이용권이 열렸어요';

  @override
  String get proPurchaseFailed => '결제를 마치지 못했어요';

  @override
  String get proRestoreNone => '복원할 구매가 없어요';

  @override
  String get proRestoreDone => '구매를 복원했어요';

  @override
  String get proChipFree => 'FREE';

  @override
  String get proChipPro => 'PRO';

  @override
  String get proInfoTitle => '이용권 정보';

  @override
  String get proInfoStatus => '상태';

  @override
  String get proInfoStatusActive => '사용 중';

  @override
  String get proInfoSource => '열린 방식';

  @override
  String get proSourcePurchase => '구매';

  @override
  String get proInfoPurchasedAt => '구매일';

  @override
  String get proInfoOrderId => '주문 번호';

  @override
  String get proInfoUnknown => '확인 중';

  @override
  String get proInfoNotePurchase =>
      '이 기기의 Google Play 계정으로 구매됐어요. 기기를 바꿔도 같은 계정이면 \"구매 복원\"으로 다시 열려요.';

  @override
  String get proInfoNotePurchaseAppStore =>
      '이 기기의 Apple 계정으로 구매됐어요. 기기를 바꿔도 같은 Apple 계정이면 \"구매 복원\"으로 다시 열려요.';

  @override
  String get proInfoRestore => '구매 복원';

  @override
  String get proSheetRedeem => '프로모션 코드 사용';

  @override
  String get homeStatusSheetTitle => '지금 상태';

  @override
  String get homeStatusWatchingDescription => '켜 둔 장소에 도착하거나 출발하면 알려요';

  @override
  String get homeStatusOffDescription =>
      '켜진 장소가 있는데 감시가 멈춰 있어요. 위치 권한을 확인해 주세요';

  @override
  String get homeStatusCheckingDescription => '감시 상태를 확인하고 있어요';

  @override
  String get homeStatusIdleDescription => '켜진 장소가 없어요. 장소를 켜면 감시가 시작돼요';

  @override
  String get homeAudioHeadphonesDescription => '이어폰으로 소리와 진동이 와요';

  @override
  String get homeAudioVibrationOnlyDescription => '이어폰이 없어서 진동으로만 알려요';

  @override
  String get homeStatusFixButton => '권한 확인하러 가기';
}
