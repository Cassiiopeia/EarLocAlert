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
      '휴대폰이 절전에 들어가거나 다른 앱을 보고 있으면, 도착 알림이 늦게 오거나 작은 알림으로만 지나갑니다.\n\n다음 세 가지를 켜면 화면을 덮는 알림이 해제할 때까지 계속됩니다.\n\n• 배터리 사용량 최적화 제외 — 절전 중에도 제때 알립니다\n• 다른 앱 위에 표시 — 영상을 보는 중에도 알림 화면이 뜹니다\n• 전체 화면 알림 — 화면이 꺼져 있어도 깨웁니다';

  @override
  String get permissionReliabilityAction => '세 가지 모두 켜기';

  @override
  String get permissionReliabilityFootnote =>
      '설정 화면이 차례로 열립니다. 건너뛰면 알림 화면이 저절로 뜨지 않아, 진동을 끄려면 알림을 눌러 앱을 열어야 합니다.';

  @override
  String get permissionOpenSettingsTitle => '설정에서 권한을 켜주세요';

  @override
  String get permissionOpenSettingsBody =>
      '권한이 거부된 상태라 앱에서 다시 요청할 수 없습니다. 설정 화면에서 직접 허용해주세요.';

  @override
  String get permissionOpenSettingsAction => '설정 열기';

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
  String get settingsPreviewTitle => '알림 미리보기';

  @override
  String get settingsPreviewSubtitle => '알림 화면과 진동을 지금 확인합니다';

  @override
  String get settingsSectionReach => '알림 도달 권한';

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
  String get diagnosticsExportEmpty => '내보낼 기록이 없습니다';

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
  String get routeDeletedSound => '삭제된 음원 (기본음으로 알림)';

  @override
  String get routePreviewPlaceName => '테스트 장소';

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
  String get alertDismissedConfirm => '확인';

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
  String get placeSearchUnavailable => '검색을 사용할 수 없습니다 — 지도를 움직여 위치를 맞춰주세요';

  @override
  String placePickerRadius(int meters) {
    return '알림 반경 ${meters}m';
  }

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
  String get placeEmptyTitle => '첫 장소를 등록해보세요';

  @override
  String get placeEmptyBody => '내릴 정류장, 약속 장소, 집 —\n도착하거나 떠날 때 조용히 알려드립니다.';

  @override
  String get placeEmptyAction => '장소 등록';

  @override
  String get placeHomeLocationUnavailable => '현재 위치를 확인할 수 없습니다. 위치 권한을 확인해주세요';

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
  String get placeHomeWeakTitle => '알림을 놓칠 수 있습니다';

  @override
  String get placeHomeWeakPowerSaving => '절전 중이거나 다른 앱을 쓰는 동안 알림이 약해집니다';

  @override
  String placeHomeWeakMissing(String items) {
    return '$items 꺼짐 — 눌러서 켜기';
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
  String get scheduleAlwaysHint => '항상 알림 — 시간대를 더하면 그 시간에만 울립니다';

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
    return '종료가 시작보다 이르므로 자정을 넘긴 것으로 봅니다 — $window';
  }

  @override
  String get scheduleSameStartEnd =>
      '시작과 종료가 같습니다. 하루 종일 알리려면 시간대를 만들지 않으면 됩니다.';

  @override
  String get scheduleSave => '저장';

  @override
  String get scheduleAddButton => '추가';

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
}
