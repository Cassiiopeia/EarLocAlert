// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'イヤホン位置通知';

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

  @override
  String get permissionContinue => '続ける';

  @override
  String get permissionLocalOnlyFootnote => '位置情報は端末内にのみ保存され、どこにも送信されません。';

  @override
  String get permissionLocationTitle => '位置情報の権限が必要です';

  @override
  String get permissionLocationBody => 'アラートを設定する場所を地図で選び、現在地を表示するために使います。';

  @override
  String get permissionBackgroundTitle => '「常に許可」が必要です';

  @override
  String get permissionBackgroundBody =>
      'アプリを開いていなくても到着と出発をお知らせするには、バックグラウンドで位置を確認する必要があります。\n\nこの権限がないと画面を見続けなければならず、アラートの意味がなくなります。';

  @override
  String get permissionBackgroundActionAndroid => '設定で「常に許可」';

  @override
  String get permissionBackgroundFootnoteAndroid =>
      '設定画面で位置情報の権限を「常に許可」に変更してください。\n位置情報は端末内にのみ保存され、どこにも送信されません。';

  @override
  String get permissionNotificationTitle => '通知の権限が必要です';

  @override
  String get permissionNotificationBody => '到着時や出発時にお知らせするために使います。';

  @override
  String get permissionReliabilityTitle => 'アラートを見逃さないために';

  @override
  String get permissionReliabilityBody =>
      'スマートフォンが省電力状態のときや他のアプリを見ているときは、到着アラートが遅れたり、小さな通知だけで終わったりします。\n\n次の3つをオンにすると、画面いっぱいに表示されるアラートを止めるまで鳴り続けます。\n\n• バッテリー最適化の除外：省電力中でも時間どおりに知らせます\n• 他のアプリの上に表示：動画を見ている間もアラート画面が表示されます\n• 全画面通知：画面が消えていても自動で点灯します';

  @override
  String get permissionReliabilityAction => '3つすべてオンにする';

  @override
  String get permissionReliabilityFootnote =>
      '設定画面が順番に開きます。スキップするとアラート画面が自動で表示されず、バイブレーションを止めるには通知をタップしてアプリを開く必要があります。';

  @override
  String get permissionOpenSettingsTitle => '設定で変更してください';

  @override
  String get permissionOpenSettingsBody =>
      'この権限はアプリ内から再度リクエストできません。設定を開いて、次のように変更してください。';

  @override
  String get permissionOpenSettingsAction => '設定を開く';

  @override
  String get permissionSettingsLocationRow => '位置情報 → このAppの使用中、または常に';

  @override
  String get permissionSettingsBackgroundRowIos => '位置情報 → 常に';

  @override
  String get permissionSettingsBackgroundRowAndroid => '位置情報 → 常に許可';

  @override
  String get permissionSettingsNotificationRow => '通知 → 通知を許可';

  @override
  String get permissionSettingsReturnHintIos =>
      '変更したら、画面左上の「◀ アプリ名」をタップするとアプリに戻れます。位置情報の権限を変えると、アプリが再起動することがあります。';

  @override
  String get permissionSettingsReturnHintAndroid => '変更したら、戻るボタンでアプリに戻ってください。';

  @override
  String get permissionDoneTitle => '準備ができました';

  @override
  String get permissionDoneBody => '場所を登録すると、到着と出発をお知らせします。';

  @override
  String get permissionDoneAction => 'はじめる';

  @override
  String get onboardingSkip => 'あとで';

  @override
  String get onboardingErrorTitle => '権限の状態を確認できませんでした';

  @override
  String get onboardingErrorHint => 'しばらくしてからもう一度お試しください。';

  @override
  String get onboardingRetry => '再試行';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionAlert => 'アラート';

  @override
  String get settingsVibrationTitle => 'バイブレーションの強さ';

  @override
  String get settingsVibrationSubtitle => 'イヤホンがないときはバイブレーションだけでお知らせします';

  @override
  String get settingsVolumeTitle => 'アラート音の大きさ';

  @override
  String get settingsVolumeSubtitle => 'イヤホンで聞こえる音の大きさ';

  @override
  String get settingsSectionReach => 'アラートを届けるための権限';

  @override
  String get settingsSectionGeneral => '一般';

  @override
  String get settingsSectionTroubleshoot => 'トラブルシューティング';

  @override
  String get settingsDiagnosticsTitle => '動作ログ';

  @override
  String get settingsDiagnosticsSubtitle => 'アラートがいつなぜ鳴ったかの記録を確認し、書き出します';

  @override
  String get settingsPermissionGranted => '許可済み';

  @override
  String get settingsPermNotifyTitle => '通知の表示';

  @override
  String get settingsPermNotifyDesc => 'オフのままだと、到着してもアラートが表示されません';

  @override
  String get settingsPermBatteryTitle => 'バッテリー最適化の除外';

  @override
  String get settingsPermBatteryDesc => 'オフのままだと、省電力中はアラートが遅れたり届かなかったりします';

  @override
  String get settingsPermOverlayTitle => '他のアプリの上に表示';

  @override
  String get settingsPermOverlayDesc => 'オフのままだと、アプリの使用中にアラート画面が表示されません';

  @override
  String get settingsPermFullScreenTitle => '全画面通知';

  @override
  String get settingsPermFullScreenDesc => 'オフのままだと、画面が消えているときにアラート画面が表示されません';

  @override
  String get diagnosticsTitle => '動作ログ';

  @override
  String get diagnosticsRefresh => '更新';

  @override
  String get diagnosticsClear => '消去';

  @override
  String get diagnosticsCancel => 'キャンセル';

  @override
  String get diagnosticsExport => '書き出す';

  @override
  String get diagnosticsExportSubject => 'イヤホン位置通知 動作ログ';

  @override
  String get diagnosticsCopied => 'クリップボードにコピーしました';

  @override
  String get diagnosticsClearTitle => '記録を消去しますか？';

  @override
  String get diagnosticsClearBody => '消去した記録は元に戻せません。';

  @override
  String diagnosticsHeader(int lineCount, String size, String maxSize) {
    return '$lineCount件 · $size / 最大 $maxSize\n端末内にのみ保存され、送信されません。いっぱいになると古いものから消えます。';
  }

  @override
  String get diagnosticsReadFailed => '記録を読み込めませんでした。';

  @override
  String get diagnosticsEmpty => 'まだ記録がありません。\nアプリを再起動するか監視が始まると記録されます。';

  @override
  String get diagnosticsCopyAll => 'すべてコピー';

  @override
  String get diagnosticsAppState => 'アプリの状態';

  @override
  String get diagnosticsAppStateHint => '権限・場所・設定・端末の状態です。書き出しに含まれます';

  @override
  String get diagnosticsSearchHint => 'タグ・場所・内容を検索';

  @override
  String diagnosticsProblemsOnly(int count) {
    return '問題のみ $count';
  }

  @override
  String get diagnosticsAllSources => 'すべて';

  @override
  String get diagnosticsSourceApp => 'アプリ';

  @override
  String get diagnosticsSourceBackground => 'バックグラウンド';

  @override
  String get diagnosticsSourceNative => 'ネイティブ';

  @override
  String get diagnosticsSourceIos => 'iOS';

  @override
  String diagnosticsShownCount(int shown) {
    return '$shown件を表示中';
  }

  @override
  String diagnosticsPeriod(String from, String to) {
    return '期間 $from 〜 $to';
  }

  @override
  String get diagnosticsNoMatch => '条件に合う記録がありません。';

  @override
  String get routeDeletedSound => '削除された音源（標準音で通知）';

  @override
  String get notificationChannelName => '到着・出発アラート';

  @override
  String get notificationChannelDescription =>
      '登録した場所に到着したとき、または出発したときにお知らせします';

  @override
  String get notificationArrived => '到着しました';

  @override
  String get notificationLeft => '離れました';

  @override
  String get alertScreenLeft => '離れました';

  @override
  String get alertScreenArrived => '到着しました';

  @override
  String alertScreenTimeAm(String hour, String minute) {
    return '午前 $hour:$minute';
  }

  @override
  String alertScreenTimePm(String hour, String minute) {
    return '午後 $hour:$minute';
  }

  @override
  String get alertScreenRouteHeadphones => 'イヤホンでお知らせ中';

  @override
  String get alertScreenRouteSoundFailed => '音を再生できず、バイブレーションでお知らせ中';

  @override
  String get alertScreenRouteVibrationOnly => 'バイブレーションのみでお知らせ中';

  @override
  String get alertScreenDismiss => 'アラートを止める';

  @override
  String get alertAlarmOpenApp => 'アプリを開く';

  @override
  String alertScreenRadius(int meters) {
    return '半径 $meters m';
  }

  @override
  String get alertNotificationChannelName => 'アラート作動中';

  @override
  String get alertNotificationChannelDescription => 'アラート画面から離れたときに戻るための通知です';

  @override
  String get alertDismissedTitle => 'アラートを止めました';

  @override
  String get volumeTitle => 'アラート音の大きさ';

  @override
  String get volumeDescription =>
      'アラートが鳴るときにシステム音量がこの値より低い場合はここまで上げ、解除すると元に戻します。';

  @override
  String get volumePreviewStop => '試聴を停止';

  @override
  String get volumePreviewNoHeadphones => 'イヤホンが接続されていないため試聴できません。';

  @override
  String get volumePreviewFailed => '再生に失敗しました。';

  @override
  String get vibrationTitle => 'バイブレーションの強さ';

  @override
  String get vibrationDescription =>
      'イヤホンが接続されていないときはバイブレーションのみでお知らせします。選ぶとその強さで一度振動します。';

  @override
  String get vibrationWeak => '弱';

  @override
  String get vibrationNormal => '標準';

  @override
  String get vibrationStrong => '強';

  @override
  String get vibrationWeakHint => '静かな場所で周りに聞こえないように';

  @override
  String get vibrationNormalHint => '初期設定';

  @override
  String get vibrationStrongHint => 'ポケットやバッグの中でも感じられるように';

  @override
  String get soundPreview => '試聴';

  @override
  String get soundCancel => 'キャンセル';

  @override
  String get soundDelete => '削除';

  @override
  String get soundDone => '完了';

  @override
  String get soundPickerTitle => 'アラート音';

  @override
  String get soundPickerPresetHeader => '内蔵のアラート音';

  @override
  String soundPickerCustomHeader(int count, int max) {
    return '登録した音源  $count/$max';
  }

  @override
  String get soundPickerCustomEmpty => '端末にある音声ファイルを登録して使えます。';

  @override
  String get soundPickerAdd => '音源を追加';

  @override
  String get soundPickerChecking => '確認中…';

  @override
  String get soundPickerHeadphoneNotice =>
      'イヤホンを接続すると試聴できます。アラート音はイヤホン接続時のみ再生されます。';

  @override
  String get soundPreviewFailed => 'この音源は再生できません';

  @override
  String get soundSaveFailed => '音源を保存できませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get soundDeleteTitle => '音源を削除しますか？';

  @override
  String soundDeleteBody(String name) {
    return '$name\n\nこの音源を使っていた場所は標準音でお知らせします。';
  }

  @override
  String soundDurationMinutesSeconds(int minutes, int seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String soundImportLimitReached(int max) {
    return '音源は最大$max件まで登録できます。使っていない音源を削除してからもう一度お試しください。';
  }

  @override
  String soundImportNoExtension(String allowed) {
    return '拡張子のないファイルです。$allowed 形式のみ使えます。';
  }

  @override
  String soundImportUnsupported(String extension, String allowed) {
    return '$extension 形式は使えません。$allowed のみ対応しています。';
  }

  @override
  String soundImportTooLarge(String size, String max) {
    return 'ファイルが大きすぎます（$size / 最大 $max）。';
  }

  @override
  String soundImportTooLong(String duration, String max) {
    return '長すぎます（$duration / 最大 $max）。アラート音は繰り返し再生されるので短くても問題ありません。';
  }

  @override
  String get soundImportNotPlayable => '再生できないファイルです。別のファイルを選んでください。';

  @override
  String get soundPresetDefault => '標準音';

  @override
  String get soundPresetBell => 'ベル';

  @override
  String get soundPresetElectronic => '電子音';

  @override
  String get soundPresetSiren => 'サイレン';

  @override
  String get soundPresetChime => 'チャイム';

  @override
  String get placeSearchUnnamed => '名称のない場所';

  @override
  String get placePickerTitle => '地図で選択';

  @override
  String get placeMyLocation => '現在地';

  @override
  String get placeSearchHint => '場所・住所を検索';

  @override
  String get placeSearchUnavailable => '検索を利用できません。地図を動かして位置を合わせてください';

  @override
  String get placePickerPinHint => '地図を動かしてピンを合わせてください';

  @override
  String get placePickerConfirm => 'この場所に決定';

  @override
  String get placeDirectionEnter => '到着アラート';

  @override
  String get placeDirectionExit => '出発アラート';

  @override
  String get placeDirectionBoth => '到着・出発';

  @override
  String placeRadiusInfo(String direction, int meters) {
    return '$direction · 半径 $meters m';
  }

  @override
  String placeDeleted(String name) {
    return '「$name」を削除しました';
  }

  @override
  String get placeUndo => '元に戻す';

  @override
  String get placeSwipeDeleteLabel => '削除';

  @override
  String get placeFormDelete => 'この場所を削除';

  @override
  String get placeFormDeleteTitle => 'この場所を削除しますか？';

  @override
  String placeFormDeleteBody(String name) {
    return '「$name」をリストから削除します。削除した直後なら元に戻せます。';
  }

  @override
  String get placeDeleteCancel => 'キャンセル';

  @override
  String get placeFormLeaveTitle => '保存せずに戻りますか？';

  @override
  String get placeFormLeaveBody => 'ここまでの変更は失われます。';

  @override
  String get placeFormKeepEditing => '編集を続ける';

  @override
  String get placeFormLeave => '編集をやめる';

  @override
  String get placeFormTitleNew => '場所を登録';

  @override
  String get placeFormTitleEdit => '場所を編集';

  @override
  String get placeFormNameLabel => '名前';

  @override
  String get placeFormNameHint => '例：降りるバス停、待ち合わせ場所';

  @override
  String get placeFormLocationLabel => '位置';

  @override
  String get placeFormPickOnMap => '地図で選択';

  @override
  String get placeFormRepickOnMap => '地図で選び直す';

  @override
  String get placeFormNoLocation => 'まだ位置を選んでいません';

  @override
  String placeFormCoordinates(String value) {
    return '座標  $value';
  }

  @override
  String get placeFormCoordinatesManual => '座標を直接入力';

  @override
  String get placeFormLatitude => '緯度';

  @override
  String get placeFormLongitude => '経度';

  @override
  String get placeFormRadiusLabel => 'アラート半径';

  @override
  String placeFormRadiusValue(int meters) {
    return '$meters m';
  }

  @override
  String get placeFormTimingLabel => 'アラートのタイミング';

  @override
  String get placeFormTimingEnter => '到着';

  @override
  String get placeFormTimingExit => '出発';

  @override
  String get placeFormTimingBoth => '両方';

  @override
  String get placeFormSoundTitle => 'イヤホンで音を鳴らす';

  @override
  String get placeFormSoundDescription =>
      'イヤホン（有線・USB-C・Bluetooth）が接続されているときだけ音が鳴ります。\nスピーカーからは絶対に鳴りません。';

  @override
  String get placeFormSoundLabel => 'アラート音';

  @override
  String get placeFormCustomSound => '登録した音源';

  @override
  String get placeFormSubmitNew => '登録';

  @override
  String get placeFormSubmitSave => '保存';

  @override
  String get placeErrorEmptyName => '名前を入力してください';

  @override
  String placeErrorRadius(int min, int max) {
    return '半径は $min m ～ $max m の範囲で指定してください';
  }

  @override
  String get placeErrorCoordinates => '位置の座標が正しくありません';

  @override
  String placeErrorLimit(int max) {
    return '場所は最大 $max 件まで登録できます';
  }

  @override
  String get placeErrorEmptyWindow => '時間帯の開始と終了が同じです。一日中通知するには時間帯を削除してください';

  @override
  String get placeErrorNoDays => '時間帯の曜日を1つ以上選んでください';

  @override
  String get placeEmptyTitle => '最初の場所を登録しましょう';

  @override
  String get placeEmptyAction => '場所を登録';

  @override
  String get placeHomeLocationUnavailable => '現在地を取得できません。位置情報の権限を確認してください';

  @override
  String get placeLocationSlow => '現在地の取得に時間がかかっています。少ししてからもう一度押してください';

  @override
  String get placeHomeStatusWatching => '監視中';

  @override
  String get placeHomeStatusOff => '監視オフ';

  @override
  String get placeHomeStatusChecking => '確認中';

  @override
  String get placeHomeStatusIdle => '待機中';

  @override
  String get placeHomeAudioHeadphones => 'イヤホン';

  @override
  String get placeHomeAudioVibrationOnly => '振動のみ';

  @override
  String get placeHomeWeakTitle => 'アラートが鳴らないかも';

  @override
  String get placeHomeWeakChip => '通知が弱い';

  @override
  String get placeHomeWeakFixButton => 'オンにする';

  @override
  String get placeHomeWeakPowerSaving => '省電力中や他のアプリの使用中はアラートが弱まります';

  @override
  String placeHomeWeakMissing(String items) {
    return '$itemsがオフです · タップしてオンにする';
  }

  @override
  String get placeHomeAddPlace => '場所を追加';

  @override
  String get placeHomeLoadFailed => '場所を読み込めませんでした';

  @override
  String get placeHomeSettings => '設定';

  @override
  String get scheduleTitle => 'アラートの時間帯';

  @override
  String get scheduleAlways => '常にアラート';

  @override
  String get scheduleAlwaysHint => '常にアラート。時間帯を追加すると、その時間だけ鳴ります';

  @override
  String get scheduleAdd => '時間帯を追加';

  @override
  String get scheduleRemove => 'この時間帯を削除';

  @override
  String get scheduleSheetAddTitle => '時間帯を追加';

  @override
  String get scheduleSheetEditTitle => '時間帯を編集';

  @override
  String get scheduleDaysLabel => '曜日';

  @override
  String get scheduleEveryday => '毎日';

  @override
  String get scheduleWeekdays => '平日';

  @override
  String get scheduleWeekends => '週末';

  @override
  String get scheduleDayMon => '月';

  @override
  String get scheduleDayTue => '火';

  @override
  String get scheduleDayWed => '水';

  @override
  String get scheduleDayThu => '木';

  @override
  String get scheduleDayFri => '金';

  @override
  String get scheduleDaySat => '土';

  @override
  String get scheduleDaySun => '日';

  @override
  String get scheduleStart => '開始';

  @override
  String get scheduleEnd => '終了';

  @override
  String scheduleCrossesMidnight(String window) {
    return '終了が開始より早いため、深夜0時をまたぐものとして扱います（$window）';
  }

  @override
  String get scheduleSameStartEnd => '開始と終了が同じです。一日中通知するには、時間帯を設定しないでください。';

  @override
  String get scheduleSave => '保存';

  @override
  String get scheduleAddButton => '追加';

  @override
  String get settingsWatchTitle => 'ウォッチで通知を受け取る';

  @override
  String get settingsWatchSubtitle => 'スマートウォッチで到着通知を受け取る方法';

  @override
  String get watchGuideIntro =>
      'スマートウォッチを着けている場合、ウォッチでも通知を受け取れます。ウォッチ側の設定を一度オンにしてください。';

  @override
  String get watchGuideAndroidStep1 =>
      'スマートフォンで Galaxy Wearable などのウォッチアプリを開きます';

  @override
  String get watchGuideAndroidStep2 => 'ウォッチ設定 → 通知 → アプリの通知を開きます';

  @override
  String watchGuideAndroidStep3(String appName) {
    return '一覧の「$appName」をオンにします';
  }

  @override
  String get watchGuideIosStep1 => 'iPhone で Watch アプリを開きます';

  @override
  String get watchGuideIosStep2 => '「通知」を開きます';

  @override
  String watchGuideIosStep3(String appName) {
    return '「$appName」が表示されていればオンにします。iPhone がロック中にウォッチへ通知されます';
  }

  @override
  String get watchGuideNote => 'ウォッチの振動はウォッチの設定によって異なる場合があります。';

  @override
  String get watchGuideConfirm => 'わかりました';

  @override
  String get settingsThemeTitle => '画面モード';

  @override
  String get themeSystem => '端末の設定に従う';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeSheetHint => 'アラート画面はまぶしくならないよう常に暗く表示されます。';

  @override
  String get themeChanged => '画面モードを変更しました';

  @override
  String get themeUndo => '元に戻す';

  @override
  String get placeFormSaveFailed => '保存できませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get scheduleCancel => 'キャンセル';

  @override
  String scheduleWindow(String days, String start, String end) {
    return '$days $start ~ $end';
  }

  @override
  String scheduleWindowNextDay(String days, String start, String end) {
    return '$days $start ~ $end（翌日）';
  }

  @override
  String scheduleTimeRange(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String scheduleTimeRangeNextDay(String start, String end) {
    return '$start ~ $end（翌日）';
  }

  @override
  String scheduleMore(String first, int count) {
    return '$first ほか$count件';
  }

  @override
  String get appUpdateReady => '新しいバージョンをダウンロードしました';

  @override
  String get appUpdateRestart => '再起動';

  @override
  String get settingsVersionTitle => 'アプリのバージョン';

  @override
  String get settingsVersionCheck => 'アップデートを確認';

  @override
  String get appUpdateNone => '今のところ利用できるアップデートはありません';

  @override
  String get settingsSectionAbout => '情報';

  @override
  String get settingsTermsTitle => '利用規約';

  @override
  String get settingsPrivacyTitle => 'プライバシーポリシー';

  @override
  String get settingsLicensesTitle => 'オープンソースライセンス';

  @override
  String get settingsAdPrivacyTitle => '広告のプライバシー設定';

  @override
  String get settingsAdPrivacySubtitle => '広告に関する同意の選択を確認または変更します';

  @override
  String get settingsOpenLinkFailed => 'リンクを開けませんでした。ブラウザがインストールされているか確認してください';

  @override
  String get settingsLockAlarmTitle => 'ロック画面アラーム';

  @override
  String get settingsLockAlarmOn => '画面が消えているときは、ロック画面全体にアラームを表示します';

  @override
  String get settingsLockAlarmNotDetermined =>
      '許可すると、画面が消えているときにロック画面全体にアラームを表示します';

  @override
  String get settingsLockAlarmDenied => 'オフです。設定でアラームを許可すると、ロック画面全体にアラームを表示します';

  @override
  String get settingsLockAlarmNeedsNewerOs =>
      '画面全体を覆うアラームは iOS 26 以降で使えます。今は通知と振動でお知らせします。';

  @override
  String get settingsLockAlarmAllow => '許可';

  @override
  String get settingsLockAlarmOpenSettings => '設定を開く';

  @override
  String get settingsVibrationTestTitle => 'バイブレーションのテスト';

  @override
  String get vibrationCheckTitle => '画面が消えていても\n振動するか確認します';

  @override
  String get vibrationCheckDescription =>
      'イヤホンがないときは振動が唯一の通知です。iPhone の設定で振動が止まっていることがあります。';

  @override
  String get vibrationCheckItemNotifications => '通知を許可';

  @override
  String get vibrationCheckItemLockScreen => 'ロック画面に表示';

  @override
  String get vibrationCheckItemSound => '通知のサウンド';

  @override
  String get vibrationCheckItemHaptics => '触覚・バイブレーション';

  @override
  String get vibrationCheckStatusOn => 'オン';

  @override
  String get vibrationCheckStatusOff => 'オフ';

  @override
  String get vibrationCheckStatusByTest => 'テストで確認';

  @override
  String get vibrationCheckBlockedHint =>
      'オフの項目を先にオンにしてください。通知のサウンドがオフだと振動も止まります。音は鳴らない通知音です。';

  @override
  String get vibrationCheckOpenNotificationSettings => '通知設定を開く';

  @override
  String get vibrationCheckSendTest => 'テスト通知を送る';

  @override
  String get vibrationCheckLater => 'あとで';

  @override
  String get vibrationCheckScheduleFailed => 'テスト通知を送れませんでした。もう一度押してください。';

  @override
  String get vibrationCheckNotificationTitle => '振動チェック';

  @override
  String get vibrationCheckNotificationBody => '振動しましたか?アプリに戻って教えてください';

  @override
  String get vibrationCheckWaitingTitle => '今すぐ画面をロックしてください';

  @override
  String vibrationCheckWaitingBody(int seconds) {
    return '$seconds秒後に到着通知と同じ通知が届きます。振動するか確かめてください。';
  }

  @override
  String get vibrationCheckCancel => 'キャンセル';

  @override
  String get vibrationCheckNotLockedTitle => '画面がロックされていません';

  @override
  String get vibrationCheckNotLockedBody =>
      'アプリが開いたままだと実際の到着と違うためテストになりません。ボタンを押したらすぐ画面をロックしてください。';

  @override
  String get vibrationCheckTryAgain => 'もう一度テスト';

  @override
  String get vibrationCheckAskTitle => '通知が届いたとき\n振動を感じましたか?';

  @override
  String get vibrationCheckAskBody => '音が鳴らないのは正常です。振動だけ確認してください。';

  @override
  String get vibrationCheckAnswerFelt => '感じた';

  @override
  String get vibrationCheckAnswerNotFelt => '感じなかった';

  @override
  String get vibrationCheckAnswerNoNotification => '通知が来なかった';

  @override
  String get vibrationCheckGuideHapticsEyebrow => 'いちばん多い原因';

  @override
  String get vibrationCheckGuideHapticsTitle => '触覚を「常に再生」に';

  @override
  String get vibrationCheckGuideAccessibilityEyebrow => '端末全体の振動スイッチ';

  @override
  String get vibrationCheckGuideAccessibilityTitle => 'バイブレーションをオン';

  @override
  String get vibrationCheckGuideAccessibilityHint =>
      'このスイッチがオフだと電話と通知の振動がすべて止まります。';

  @override
  String get vibrationCheckGuideFocusEyebrow => '最後の確認';

  @override
  String get vibrationCheckGuideFocusTitle => '集中モードでこのアプリを許可';

  @override
  String get vibrationCheckGuideFocusHint => '集中モードを使っていなければ飛ばして大丈夫です。';

  @override
  String get vibrationCheckGuideOpenSettingsHint =>
      '「設定を開く」はこのアプリの設定ページを開きます。左上の戻るボタンで設定の最初の画面へ移動してください。';

  @override
  String get vibrationCheckOpenSettings => '設定を開く';

  @override
  String get vibrationCheckGuideChanged => '変更した';

  @override
  String get vibrationCheckGuideStillNot => 'それでもだめなら';

  @override
  String get vibrationCheckSuccessTitle => '準備できました';

  @override
  String get vibrationCheckSuccessBody => 'イヤホンがなくても到着すると\n画面が消えたまま振動します。';

  @override
  String get vibrationCheckDone => 'OK';

  @override
  String get vibrationCheckStillTitle => 'ほかのアプリの通知は振動しますか?';

  @override
  String get vibrationCheckStillBody =>
      'メッセージでも振動しないなら端末の設定です。着信音の触覚パターンが「なし」になっていないか確認してください。';

  @override
  String get vibrationCheckClose => '閉じる';

  @override
  String get iosSettingsRoot => '設定';

  @override
  String get iosSettingsSoundsAndHaptics => 'サウンドと触覚';

  @override
  String get iosSettingsHaptics => '触覚';

  @override
  String get iosSettingsHapticsAlways => '常に再生';

  @override
  String get iosSettingsHapticsSilentOnly => '消音モードで再生';

  @override
  String get iosSettingsHapticsNotInSilent => '消音モードで再生しない';

  @override
  String get iosSettingsHapticsNever => '再生しない';

  @override
  String get iosSettingsAccessibility => 'アクセシビリティ';

  @override
  String get iosSettingsTouch => 'タッチ';

  @override
  String get iosSettingsTapToWake => 'タップしてスリープ解除';

  @override
  String get iosSettingsShakeToUndo => 'シェイクで取り消し';

  @override
  String get iosSettingsVibration => 'バイブレーション';

  @override
  String get iosSettingsFocus => '集中モード';

  @override
  String get iosSettingsFocusMode => '使用中のモード';

  @override
  String get iosSettingsFocusAllowApp => '許可された通知 › アプリを追加';

  @override
  String get iosSettingsRingtone => '着信音';

  @override
  String get iosSettingsRingtoneHapticsNotNone => '触覚 ≠ なし';

  @override
  String get settingsVibrationCheckTitle => '通知が振動しないとき';

  @override
  String get settingsVibrationCheckSubtitle => '振動チェックと iPhone 設定ガイド';

  @override
  String get onboardingVibrationCardTitle => '振動を感じられるか確認しましょう';

  @override
  String get onboardingVibrationCardBody => 'iPhoneの振動設定がオフだと、到着しても何も感じません。';

  @override
  String get homeGapNotifications => '通知の許可';

  @override
  String get homeGapLockScreen => 'ロック画面の通知';

  @override
  String get homeGapVibration => '振動';

  @override
  String get settingsLockScreenNotifyTitle => 'ロック画面に表示';

  @override
  String get settingsLockScreenNotifyDesc => 'オフだと、画面が消えたまま到着しても何も表示されません';

  @override
  String get notificationActionDismiss => 'アラートを止める';

  @override
  String get settingsReportTitle => '問題を報告';

  @override
  String get settingsReportSubtitle => '不具合や気になる点をメールで送ります';

  @override
  String get reportSheetTitle => '問題を報告';

  @override
  String get reportSheetHint => 'メールアプリが開きます。内容を書いてご自身で送信してください。';

  @override
  String get reportAttachLog => '動作ログも一緒に送る';

  @override
  String get reportAttachLogNote =>
      '位置座標・登録した場所・設定を含むログが添付されます。送信前にメールで確認でき、ご自身で送信したときだけ送られます。';

  @override
  String get reportOpenMail => 'メールアプリを開く';

  @override
  String get reportMailSubject => '[EarLocAlert] 問題の報告';

  @override
  String get reportMailPrompt => 'どのような問題があったか書いてください。';

  @override
  String get reportMailInfoHeader => '以下は調査に必要な端末情報です。消さないでください。';

  @override
  String reportFallbackNotice(String address) {
    return 'メールアカウントがないため共有画面を開きました。宛先は $address です。';
  }

  @override
  String get reportFailed => 'メールを開けませんでした。宛先アドレスをコピーしました。';

  @override
  String get settingsSectionBackup => 'バックアップ';

  @override
  String get settingsBackupExportTitle => '場所を書き出す';

  @override
  String get settingsBackupExportSubtitle => '登録した場所をファイルに保存、または他へ送ります';

  @override
  String get settingsBackupImportTitle => '場所を読み込む';

  @override
  String get settingsBackupImportSubtitle => '書き出したファイルから場所を取り込みます';

  @override
  String get backupExportEmpty => '書き出す場所がありません';

  @override
  String get backupExportSubject => 'EarLocAlert 場所のバックアップ';

  @override
  String backupExportCustomSound(int count) {
    return '独自の音源を使う場所 $count か所は、標準の通知音で保存しました';
  }

  @override
  String get backupImportTitle => '場所を読み込みますか?';

  @override
  String backupImportBody(int count, int existing) {
    return 'ファイルに $count か所の場所が見つかりました。現在の登録は $existing か所です。すでにある場所はスキップします。';
  }

  @override
  String get backupImportAdd => '追加する';

  @override
  String get backupImportReplace => 'すべて置き換える';

  @override
  String get backupCancel => 'キャンセル';

  @override
  String get backupReplaceTitle => '現在の場所をすべて削除しますか?';

  @override
  String backupReplaceBody(int existing) {
    return '現在登録されている $existing か所が削除され、ファイルの場所に置き換わります。元に戻せません。';
  }

  @override
  String get backupReplaceConfirm => '置き換える';

  @override
  String backupImportResult(int added, int skipped) {
    return '$added か所を読み込みました。スキップ $skipped か所';
  }

  @override
  String get backupImportNone => '読み込める新しい場所がありません';

  @override
  String get backupImportInvalid => 'このアプリで書き出した場所ファイルではありません';

  @override
  String get backupImportNewer =>
      '新しいバージョンのアプリで作成されたファイルです。アプリを更新してからもう一度お試しください';

  @override
  String get backupImportReadFailed => 'ファイルを読み込めませんでした';

  @override
  String get proSheetTitle => '永久パス';

  @override
  String get proSheetSubtitle => 'サブスクではありません · 機種変更しても同じアカウントなら引き継ぎ';

  @override
  String proSheetBuy(String price) {
    return '永久パス $price';
  }

  @override
  String get proSheetRestore => '購入済みですか？復元する';

  @override
  String get proSheetColumnFree => '無料';

  @override
  String get proSheetColumnPro => 'プロ';

  @override
  String get proRowPlaces => '場所';

  @override
  String get proRowDirections => '到着・出発の通知';

  @override
  String get proRowSchedules => '通知の時間帯';

  @override
  String get proRowVibration => '振動の強さ';

  @override
  String get proRowSound => 'イヤホン通知音';

  @override
  String get proRowBackup => '場所のバックアップ';

  @override
  String get proRowAds => '広告';

  @override
  String get proValueOnePlace => '1件';

  @override
  String get proValueUnlimited => '無制限';

  @override
  String get proValueDefaultSound => '標準1つ';

  @override
  String get proValueAllSounds => 'すべて + マイ音源';

  @override
  String get proValueAdsOn => 'あり';

  @override
  String get proValueAdsOff => 'なし';

  @override
  String get proUnlockAction => '永久パスで解除';

  @override
  String get proLockedSounds => 'すべての通知音 · マイ音源';

  @override
  String get proLockedPlaces => '場所をもっと登録するには';

  @override
  String get proLockedBackup => '場所のバックアップ · 読み込み';

  @override
  String get proLockedExamplePlaceHome => '自宅';

  @override
  String get proLockedExamplePlaceStation => '駅';

  @override
  String get proCardTitle => '場所を無制限に登録しましょう';

  @override
  String get proCardSubtitle => 'すべての通知音 · バックアップ · 広告なし';

  @override
  String proCardUsage(int count, int limit) {
    return '場所 $count/$limit 使用中';
  }

  @override
  String get proRowLifetime => '永久パス';

  @override
  String get proOwnedSubtitle => 'すべての機能が使えます';

  @override
  String get proDeviceLimitReached => '端末の上限に達しました';

  @override
  String get proPriceLoading => '価格を確認中…';

  @override
  String get proProductUnavailable => '現在購入できません。しばらくしてからもう一度お試しください';

  @override
  String get proPurchasePending => '支払いが確認されると解除されます';

  @override
  String get proPurchaseDone => '永久パスが有効になりました';

  @override
  String get proPurchaseFailed => '支払いを完了できませんでした';

  @override
  String get proRestoreNone => '復元できる購入はありません';

  @override
  String get proRestoreDone => '購入を復元しました';

  @override
  String get proChipFree => 'FREE';

  @override
  String get proChipPro => 'PRO';

  @override
  String get proInfoTitle => 'パス情報';

  @override
  String get proInfoStatus => '状態';

  @override
  String get proInfoStatusActive => '利用中';

  @override
  String get proInfoSource => '解除方法';

  @override
  String get proSourcePurchase => '購入';

  @override
  String get proInfoPurchasedAt => '購入日';

  @override
  String get proInfoOrderId => '注文番号';

  @override
  String get proInfoUnknown => '確認中';

  @override
  String get proInfoNotePurchase =>
      'この端末の Google Play アカウントで購入されました。機種変更しても同じアカウントなら「購入を復元」で再び使えます。';

  @override
  String get proInfoRestore => '購入を復元';

  @override
  String get proSheetRedeem => 'プロモーションコードを使う';

  @override
  String get homeStatusSheetTitle => '現在の状態';

  @override
  String get homeStatusWatchingDescription => 'オンにした場所に到着または出発すると知らせます';

  @override
  String get homeStatusOffDescription =>
      'オンの場所があるのに監視が止まっています。位置情報の権限を確認してください';

  @override
  String get homeStatusCheckingDescription => '監視の状態を確認しています';

  @override
  String get homeStatusIdleDescription => 'オンの場所がありません。場所をオンにすると監視が始まります';

  @override
  String get homeAudioHeadphonesDescription => 'イヤホンで音と振動が届きます';

  @override
  String get homeAudioVibrationOnlyDescription => 'イヤホンがないため振動のみでお知らせします';

  @override
  String get homeStatusFixButton => '権限を確認する';
}
