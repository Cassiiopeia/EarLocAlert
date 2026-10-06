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
      'スマートフォンが省電力状態のときや他のアプリを見ているときは、到着アラートが遅れたり、小さな通知だけで終わったりします。\n\n次の3つをオンにすると、画面いっぱいに表示されるアラートを止めるまで鳴り続けます。\n\n• バッテリー最適化の除外 — 省電力中でも時間どおりに知らせます\n• 他のアプリの上に表示 — 動画を見ている間もアラート画面が表示されます\n• 全画面通知 — 画面が消えていても自動で点灯します';

  @override
  String get permissionReliabilityAction => '3つすべてオンにする';

  @override
  String get permissionReliabilityFootnote =>
      '設定画面が順番に開きます。スキップするとアラート画面が自動で表示されず、バイブレーションを止めるには通知をタップしてアプリを開く必要があります。';

  @override
  String get permissionOpenSettingsTitle => '設定で権限をオンにしてください';

  @override
  String get permissionOpenSettingsBody =>
      '権限が拒否されているため、アプリから再度リクエストできません。設定画面で直接許可してください。';

  @override
  String get permissionOpenSettingsAction => '設定を開く';

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
  String get settingsPreviewTitle => 'アラートのプレビュー';

  @override
  String get settingsPreviewSubtitle => 'アラート画面とバイブレーションを今すぐ確認します';

  @override
  String get settingsSectionReach => 'アラートを届けるための権限';

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
  String get diagnosticsExportEmpty => '書き出す記録がありません';

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
  String get routeDeletedSound => '削除された音源（標準音で通知）';

  @override
  String get routePreviewPlaceName => 'テスト用の場所';

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
  String get alertDismissedConfirm => 'OK';

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
  String get placeSearchUnavailable => '検索を利用できません — 地図を動かして位置を合わせてください';

  @override
  String placePickerRadius(int meters) {
    return 'アラート半径 $meters m';
  }

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
  String get placeEmptyBody => '降りるバス停、待ち合わせ場所、自宅 —\n到着・出発のときに静かにお知らせします。';

  @override
  String get placeEmptyAction => '場所を登録';

  @override
  String get placeHomeLocationUnavailable => '現在地を取得できません。位置情報の権限を確認してください';

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
  String get placeHomeWeakTitle => 'アラートを見逃すかもしれません';

  @override
  String get placeHomeWeakPowerSaving => '省電力中や他のアプリの使用中はアラートが弱まります';

  @override
  String placeHomeWeakMissing(String items) {
    return '$itemsがオフです — タップしてオンにする';
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
  String get scheduleAlwaysHint => '常にアラート — 時間帯を追加すると、その時間だけ鳴ります';

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
    return '終了が開始より早いため、深夜0時をまたぐものとして扱います — $window';
  }

  @override
  String get scheduleSameStartEnd => '開始と終了が同じです。一日中通知するには、時間帯を設定しないでください。';

  @override
  String get scheduleSave => '保存';

  @override
  String get scheduleAddButton => '追加';

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
}
