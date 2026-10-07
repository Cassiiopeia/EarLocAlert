// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '耳机位置提醒';

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
  String get languageChanged => '语言已切换';

  @override
  String get languageUndo => '撤销';

  @override
  String get permissionContinue => '继续';

  @override
  String get permissionLocalOnlyFootnote => '位置信息仅保存在本设备上，不会发送到任何地方。';

  @override
  String get permissionLocationTitle => '需要位置权限';

  @override
  String get permissionLocationBody => '用于在地图上选择要设置提醒的地点，并显示您当前所在的大致位置。';

  @override
  String get permissionBackgroundTitle => '需要“始终允许”';

  @override
  String get permissionBackgroundBody =>
      '要在不打开应用的情况下提醒您到达和离开，应用需要在后台确认位置。\n\n没有此权限，您就得一直盯着屏幕，提醒也就失去了意义。';

  @override
  String get permissionBackgroundActionAndroid => '在设置中选择“始终允许”';

  @override
  String get permissionBackgroundFootnoteAndroid =>
      '请在设置页面将位置权限改为“始终允许”。\n位置信息仅保存在本设备上，不会发送到任何地方。';

  @override
  String get permissionNotificationTitle => '需要通知权限';

  @override
  String get permissionNotificationBody => '用于在您到达或离开时通知您。';

  @override
  String get permissionReliabilityTitle => '为了不错过提醒';

  @override
  String get permissionReliabilityBody =>
      '手机处于省电状态或正在使用其他应用时，到达提醒可能会延迟，或只显示为一条小通知。\n\n开启以下三项后，全屏提醒会一直持续到您关闭为止。\n\n• 忽略电池优化 — 省电时也能准时提醒\n• 显示在其他应用的上层 — 看视频时也会弹出提醒界面\n• 全屏通知 — 屏幕熄灭时也会自动点亮';

  @override
  String get permissionReliabilityAction => '全部开启';

  @override
  String get permissionReliabilityFootnote =>
      '设置页面会依次打开。如果跳过，提醒界面不会自动弹出，要停止振动就需要点击通知打开应用。';

  @override
  String get permissionOpenSettingsTitle => '请在设置中修改';

  @override
  String get permissionOpenSettingsBody => '应用内无法再次请求这项权限。请打开设置，按下面的方式修改。';

  @override
  String get permissionOpenSettingsAction => '打开设置';

  @override
  String get permissionSettingsLocationRow => '位置 → 使用App期间 或 始终';

  @override
  String get permissionSettingsBackgroundRowIos => '位置 → 始终';

  @override
  String get permissionSettingsBackgroundRowAndroid => '位置 → 始终允许';

  @override
  String get permissionSettingsNotificationRow => '通知 → 允许通知';

  @override
  String get permissionSettingsReturnHintIos =>
      '修改后，点击屏幕左上角的“◀ 应用名称”即可返回应用。更改位置权限后，应用可能会重新启动。';

  @override
  String get permissionSettingsReturnHintAndroid => '修改后，请用返回键回到应用。';

  @override
  String get permissionDoneTitle => '准备就绪';

  @override
  String get permissionDoneBody => '现在添加地点，就会在您到达和离开时提醒您。';

  @override
  String get permissionDoneAction => '开始使用';

  @override
  String get onboardingSkip => '稍后再说';

  @override
  String get onboardingErrorTitle => '无法确认权限状态';

  @override
  String get onboardingErrorHint => '请稍后重试。';

  @override
  String get onboardingRetry => '重试';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionAlert => '提醒';

  @override
  String get settingsVibrationTitle => '振动强度';

  @override
  String get settingsVibrationSubtitle => '未连接耳机时仅通过振动提醒';

  @override
  String get settingsVolumeTitle => '提示音音量';

  @override
  String get settingsVolumeSubtitle => '耳机中播放的音量大小';

  @override
  String get settingsPreviewTitle => '预览提醒';

  @override
  String get settingsPreviewSubtitle => '立即查看提醒界面和振动效果';

  @override
  String get settingsSectionReach => '确保提醒送达的权限';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsSectionTroubleshoot => '问题排查';

  @override
  String get settingsDiagnosticsTitle => '运行日志';

  @override
  String get settingsDiagnosticsSubtitle => '查看并导出提醒何时、为何触发的记录';

  @override
  String get settingsPermissionGranted => '已允许';

  @override
  String get settingsPermNotifyTitle => '允许通知';

  @override
  String get settingsPermNotifyDesc => '没有此权限，到达时不会显示提醒';

  @override
  String get settingsPermBatteryTitle => '忽略电池优化';

  @override
  String get settingsPermBatteryDesc => '没有此权限，省电时提醒可能延迟或收不到';

  @override
  String get settingsPermOverlayTitle => '显示在其他应用的上层';

  @override
  String get settingsPermOverlayDesc => '没有此权限，使用应用时不会弹出提醒界面';

  @override
  String get settingsPermFullScreenTitle => '全屏通知';

  @override
  String get settingsPermFullScreenDesc => '没有此权限，屏幕关闭时不会弹出提醒界面';

  @override
  String get diagnosticsTitle => '运行日志';

  @override
  String get diagnosticsRefresh => '刷新';

  @override
  String get diagnosticsClear => '清除';

  @override
  String get diagnosticsCancel => '取消';

  @override
  String get diagnosticsExport => '导出';

  @override
  String get diagnosticsExportEmpty => '没有可导出的记录';

  @override
  String get diagnosticsExportSubject => '耳机位置提醒 运行日志';

  @override
  String get diagnosticsCopied => '已复制到剪贴板';

  @override
  String get diagnosticsClearTitle => '要清除记录吗？';

  @override
  String get diagnosticsClearBody => '清除后的记录无法恢复。';

  @override
  String diagnosticsHeader(int lineCount, String size, String maxSize) {
    return '$lineCount 条 · $size / 最大 $maxSize\n仅保存在本设备上，不会发送。存满后会从最旧的记录开始删除。';
  }

  @override
  String get diagnosticsReadFailed => '无法读取记录。';

  @override
  String get diagnosticsEmpty => '暂无记录。\n重新打开应用或开始监测后就会出现记录。';

  @override
  String get routeDeletedSound => '音源已删除（将使用默认提示音）';

  @override
  String get routePreviewPlaceName => '测试地点';

  @override
  String get notificationChannelName => '到达·离开提醒';

  @override
  String get notificationChannelDescription => '在您到达或离开已保存的地点时提醒您';

  @override
  String get notificationArrived => '已到达';

  @override
  String get notificationLeft => '已离开';

  @override
  String get alertScreenLeft => '已离开';

  @override
  String get alertScreenArrived => '已到达';

  @override
  String alertScreenTimeAm(String hour, String minute) {
    return '上午 $hour:$minute';
  }

  @override
  String alertScreenTimePm(String hour, String minute) {
    return '下午 $hour:$minute';
  }

  @override
  String get alertScreenRouteHeadphones => '正在通过耳机提醒';

  @override
  String get alertScreenRouteSoundFailed => '无法播放声音，正在通过振动提醒';

  @override
  String get alertScreenRouteVibrationOnly => '仅通过振动提醒';

  @override
  String get alertScreenDismiss => '关闭提醒';

  @override
  String alertScreenRadius(int meters) {
    return '半径 $meters 米';
  }

  @override
  String get alertNotificationChannelName => '提醒进行中';

  @override
  String get alertNotificationChannelDescription => '离开提醒界面后用于返回的通知';

  @override
  String get alertDismissedTitle => '提醒已关闭';

  @override
  String get alertDismissedConfirm => '确定';

  @override
  String get volumeTitle => '提示音音量';

  @override
  String get volumeDescription => '提醒响起时，若系统音量低于此值，会先调高到此音量，解除后恢复原状。';

  @override
  String get volumePreviewStop => '停止试听';

  @override
  String get volumePreviewNoHeadphones => '未连接耳机，无法试听。';

  @override
  String get volumePreviewFailed => '播放失败。';

  @override
  String get vibrationTitle => '振动强度';

  @override
  String get vibrationDescription => '未连接耳机时仅通过振动提醒。选择后会以该强度振动一次。';

  @override
  String get vibrationWeak => '弱';

  @override
  String get vibrationNormal => '标准';

  @override
  String get vibrationStrong => '强';

  @override
  String get vibrationWeakHint => '在安静的地方不打扰周围';

  @override
  String get vibrationNormalHint => '默认';

  @override
  String get vibrationStrongHint => '放在口袋或包里也能感觉到';

  @override
  String get soundPreview => '试听';

  @override
  String get soundCancel => '取消';

  @override
  String get soundDelete => '删除';

  @override
  String get soundDone => '完成';

  @override
  String get soundPickerTitle => '提示音';

  @override
  String get soundPickerPresetHeader => '内置提示音';

  @override
  String soundPickerCustomHeader(int count, int max) {
    return '我的音频  $count/$max';
  }

  @override
  String get soundPickerCustomEmpty => '可以添加设备上的音频文件。';

  @override
  String get soundPickerAdd => '添加音频';

  @override
  String get soundPickerChecking => '检查中…';

  @override
  String get soundPickerHeadphoneNotice => '连接耳机后即可试听。提示音仅在连接耳机时播放。';

  @override
  String get soundPreviewFailed => '无法播放此音频';

  @override
  String get soundSaveFailed => '无法保存音频，请稍后重试。';

  @override
  String get soundDeleteTitle => '删除此音频？';

  @override
  String soundDeleteBody(String name) {
    return '$name\n\n使用此音频的地点将改用默认提示音。';
  }

  @override
  String soundDurationMinutesSeconds(int minutes, int seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String soundImportLimitReached(int max) {
    return '最多可添加 $max 个音频。请删除不用的音频后重试。';
  }

  @override
  String soundImportNoExtension(String allowed) {
    return '此文件没有扩展名。仅支持 $allowed 格式。';
  }

  @override
  String soundImportUnsupported(String extension, String allowed) {
    return '不支持 $extension 格式。仅支持 $allowed。';
  }

  @override
  String soundImportTooLarge(String size, String max) {
    return '文件过大（$size / 最大 $max）。';
  }

  @override
  String soundImportTooLong(String duration, String max) {
    return '时间过长（$duration / 最长 $max）。提示音会循环播放，短一些即可。';
  }

  @override
  String get soundImportNotPlayable => '无法播放此文件，请选择其他文件。';

  @override
  String get soundPresetDefault => '默认音';

  @override
  String get soundPresetBell => '铃声';

  @override
  String get soundPresetElectronic => '电子音';

  @override
  String get soundPresetSiren => '警报声';

  @override
  String get soundPresetChime => '风铃声';

  @override
  String get placeSearchUnnamed => '未命名地点';

  @override
  String get placePickerTitle => '在地图上选择';

  @override
  String get placeMyLocation => '我的位置';

  @override
  String get placeSearchHint => '搜索地点或地址';

  @override
  String get placeSearchUnavailable => '无法使用搜索——请移动地图来确定位置';

  @override
  String get placePickerPinHint => '移动地图来放置图钉';

  @override
  String get placePickerConfirm => '选择此位置';

  @override
  String get placeDirectionEnter => '到达提醒';

  @override
  String get placeDirectionExit => '离开提醒';

  @override
  String get placeDirectionBoth => '到达·离开';

  @override
  String placeRadiusInfo(String direction, int meters) {
    return '$direction · 半径 $meters 米';
  }

  @override
  String placeDeleted(String name) {
    return '已删除“$name”';
  }

  @override
  String get placeUndo => '撤销';

  @override
  String get placeSwipeDeleteLabel => '删除';

  @override
  String get placeFormDelete => '删除此地点';

  @override
  String get placeFormDeleteTitle => '要删除此地点吗？';

  @override
  String placeFormDeleteBody(String name) {
    return '“$name”将从列表中移除。删除后可立即撤销。';
  }

  @override
  String get placeDeleteCancel => '取消';

  @override
  String get placeFormLeaveTitle => '不保存就离开吗？';

  @override
  String get placeFormLeaveBody => '已修改的内容将会丢失。';

  @override
  String get placeFormKeepEditing => '继续编辑';

  @override
  String get placeFormLeave => '离开';

  @override
  String get placeFormTitleNew => '添加地点';

  @override
  String get placeFormTitleEdit => '编辑地点';

  @override
  String get placeFormNameLabel => '名称';

  @override
  String get placeFormNameHint => '例如：下车站、约定地点';

  @override
  String get placeFormLocationLabel => '位置';

  @override
  String get placeFormPickOnMap => '在地图上选择';

  @override
  String get placeFormRepickOnMap => '重新在地图上选择';

  @override
  String get placeFormNoLocation => '尚未选择位置';

  @override
  String placeFormCoordinates(String value) {
    return '坐标  $value';
  }

  @override
  String get placeFormCoordinatesManual => '手动输入坐标';

  @override
  String get placeFormLatitude => '纬度';

  @override
  String get placeFormLongitude => '经度';

  @override
  String get placeFormRadiusLabel => '提醒半径';

  @override
  String placeFormRadiusValue(int meters) {
    return '$meters 米';
  }

  @override
  String get placeFormTimingLabel => '提醒时机';

  @override
  String get placeFormTimingEnter => '到达';

  @override
  String get placeFormTimingExit => '离开';

  @override
  String get placeFormTimingBoth => '两者';

  @override
  String get placeFormSoundTitle => '耳机提示音';

  @override
  String get placeFormSoundDescription =>
      '仅在连接耳机（有线、USB-C 或蓝牙）时才会发出声音。\n绝不会通过扬声器发出声音。';

  @override
  String get placeFormSoundLabel => '提示音';

  @override
  String get placeFormCustomSound => '我的音频';

  @override
  String get placeFormSubmitNew => '添加';

  @override
  String get placeFormSubmitSave => '保存';

  @override
  String get placeErrorEmptyName => '请输入名称';

  @override
  String placeErrorRadius(int min, int max) {
    return '半径必须在 $min 米到 $max 米之间';
  }

  @override
  String get placeErrorCoordinates => '位置坐标无效';

  @override
  String placeErrorLimit(int max) {
    return '最多可添加 $max 个地点';
  }

  @override
  String get placeErrorEmptyWindow => '时段的开始和结束相同。若要全天提醒，请删除该时段';

  @override
  String get placeErrorNoDays => '请至少为时段选择一天';

  @override
  String get placeEmptyTitle => '添加你的第一个地点';

  @override
  String get placeEmptyBody => '下车站、约定地点、家——\n到达或离开时会悄悄提醒你。';

  @override
  String get placeEmptyAction => '添加地点';

  @override
  String get placeHomeLocationUnavailable => '无法获取当前位置，请检查位置权限';

  @override
  String get placeLocationSlow => '正在获取当前位置，需要一些时间。请稍后再试';

  @override
  String get placeHomeStatusWatching => '监测中';

  @override
  String get placeHomeStatusOff => '监测已关闭';

  @override
  String get placeHomeStatusChecking => '检查中';

  @override
  String get placeHomeStatusIdle => '待机中';

  @override
  String get placeHomeAudioHeadphones => '耳机';

  @override
  String get placeHomeAudioVibrationOnly => '仅振动';

  @override
  String get placeHomeWeakTitle => '可能会错过提醒';

  @override
  String get placeHomeWeakPowerSaving => '省电模式或使用其他应用时，提醒会变弱';

  @override
  String placeHomeWeakMissing(String items) {
    return '$items 已关闭——点按开启';
  }

  @override
  String get placeHomeAddPlace => '添加地点';

  @override
  String get placeHomeLoadFailed => '无法加载地点';

  @override
  String get placeHomeSettings => '设置';

  @override
  String get scheduleTitle => '提醒时段';

  @override
  String get scheduleAlways => '始终提醒';

  @override
  String get scheduleAlwaysHint => '始终提醒——添加时段后仅在该时段响起';

  @override
  String get scheduleAdd => '添加时段';

  @override
  String get scheduleRemove => '删除此时段';

  @override
  String get scheduleSheetAddTitle => '添加时段';

  @override
  String get scheduleSheetEditTitle => '编辑时段';

  @override
  String get scheduleDaysLabel => '星期';

  @override
  String get scheduleEveryday => '每天';

  @override
  String get scheduleWeekdays => '工作日';

  @override
  String get scheduleWeekends => '周末';

  @override
  String get scheduleDayMon => '周一';

  @override
  String get scheduleDayTue => '周二';

  @override
  String get scheduleDayWed => '周三';

  @override
  String get scheduleDayThu => '周四';

  @override
  String get scheduleDayFri => '周五';

  @override
  String get scheduleDaySat => '周六';

  @override
  String get scheduleDaySun => '周日';

  @override
  String get scheduleStart => '开始';

  @override
  String get scheduleEnd => '结束';

  @override
  String scheduleCrossesMidnight(String window) {
    return '结束早于开始，因此视为跨过午夜——$window';
  }

  @override
  String get scheduleSameStartEnd => '开始和结束相同。若要全天提醒，不设置时段即可。';

  @override
  String get scheduleSave => '保存';

  @override
  String get scheduleAddButton => '添加';

  @override
  String get scheduleCancel => '取消';

  @override
  String scheduleWindow(String days, String start, String end) {
    return '$days $start ~ $end';
  }

  @override
  String scheduleWindowNextDay(String days, String start, String end) {
    return '$days $start ~ $end（次日）';
  }

  @override
  String scheduleTimeRange(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String scheduleTimeRangeNextDay(String start, String end) {
    return '$start ~ $end（次日）';
  }

  @override
  String scheduleMore(String first, int count) {
    return '$first 等 $count 项';
  }

  @override
  String get appUpdateReady => '已下载新版本';

  @override
  String get appUpdateRestart => '重启';

  @override
  String get settingsVersionTitle => '应用版本';

  @override
  String get settingsVersionCheck => '检查更新';

  @override
  String get appUpdateNone => '目前没有可用的更新';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsTermsTitle => '服务条款';

  @override
  String get settingsPrivacyTitle => '隐私政策';

  @override
  String get settingsLicensesTitle => '开源许可';

  @override
  String get settingsAdPrivacyTitle => '广告隐私设置';

  @override
  String get settingsAdPrivacySubtitle => '查看或更改你的广告同意选择';

  @override
  String get settingsOpenLinkFailed => '无法打开链接，请确认已安装浏览器';
}
