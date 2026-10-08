/// 아직 켜지지 않은 신뢰성 항목의 종류 (이슈 #115, #237)
///
/// **문구가 아니라 값이다.** 홈 상태 provider 는 `BuildContext` 가 없어 언어를
/// 모른다 — 화면(라우터)이 이 값을 현재 언어의 항목 이름으로 바꾼다 (이슈 #163).
enum ReliabilityGap {
  // Android 신뢰성 권한 (#74)
  batteryOptimization,
  overlay,
  fullScreenIntent,

  // iOS — 앱이 읽을 수 있는 알림 설정과 진동 시험 답 (#237)

  /// 알림 자체가 허용되지 않았다
  notifications,

  /// 잠금 화면에 표시가 꺼져 있다
  lockScreen,

  /// 잠금 화면 알람(AlarmKit, iOS 26+)을 거부했다
  lockScreenAlarm,

  /// 진동 시험에서 "느껴지지 않았다"고 답했다
  vibration;

  /// iOS 시스템 설정 앱에서 고치는 항목인가. 진동은 안내 시트가 따로 있다
  bool get fixedInSystemSettings =>
      this == notifications || this == lockScreen || this == lockScreenAlarm;
}
