/// iOS 진동 점검 흐름 상태 (이슈 #301)
///
/// 자동 확인 > 시험 알림 > 결과 묻기 > 단계 안내(햅틱 > 손쉬운 사용 > 집중 모드) > 끝
library;

/// 시험 알림을 보내기까지 기다리는 시간 — 버튼을 누르고 화면을 잠글 여유
const int testNotificationDelaySeconds = 5;

/// 앱이 읽을 수 있는 알림 설정 중 진동을 막는 것 3개
///
/// 햅틱·손쉬운 사용 진동·집중 모드는 iOS 가 앱에 알려주지 않아 여기 없다 — 시험으로 확인
enum VibrationCheckBlocker {
  /// 알림 자체가 허용되지 않음
  notificationsNotAllowed,

  /// 잠금 화면 표시가 꺼짐 — 화면이 꺼진 채 도착하면 아무것도 안 보인다
  lockScreenHidden,

  /// 알림 사운드가 꺼짐 — 무음 알림음에 딸린 진동도 함께 빠진다 (이슈 #221)
  notificationSoundOff,
}

/// 진동 점검 단계
enum IosVibrationCheckStep {
  /// 읽을 수 있는 설정 확인 + 시험 알림 보내기
  readiness,

  /// 시험 알림 예약 후 화면 잠금 대기
  waitingForLock,

  /// 알림 시각까지 화면을 잠그지 않음 — 앱이 켜져 있으면 실제 도착과 경로가 달라 무효
  screenNotLocked,

  /// "진동을 느꼈나요?"
  askingResult,

  /// 안내 1/3 사운드 및 햅틱 > 햅틱 > 항상 재생
  guideHaptics,

  /// 안내 2/3 손쉬운 사용 > 터치 > 진동
  guideAccessibilityVibration,

  /// 안내 3/3 집중 모드에서 이 앱 허용
  guideFocusMode,

  /// 진동을 느낌 — 끝
  succeeded,

  /// 안내를 다 해도 안 됨 — 다른 앱도 안 떨리는지 확인
  stillNotVibrating;

  /// 단계 안내 순서 (1부터). 안내 단계가 아니면 null
  int? get guidePosition => switch (this) {
    guideHaptics => 1,
    guideAccessibilityVibration => 2,
    guideFocusMode => 3,
    _ => null,
  };

  static const int guideStepCount = 3;
}

class IosVibrationCheckState {
  const IosVibrationCheckState({
    required this.step,
    required this.blockers,
    required this.hasReadSettings,
    required this.isScheduleFailed,
    required this.attempt,
  });

  static const initial = IosVibrationCheckState(
    step: IosVibrationCheckStep.readiness,
    blockers: {},
    hasReadSettings: false,
    isScheduleFailed: false,
    attempt: 0,
  );

  final IosVibrationCheckStep step;
  final Set<VibrationCheckBlocker> blockers;

  /// 설정을 한 번이라도 읽었는가 — 읽기 전에는 "켜짐"으로 단정하지 않는다
  final bool hasReadSettings;

  /// 마지막 시험 알림 예약이 실패했는가
  final bool isScheduleFailed;

  /// 시험 알림을 보낸 횟수 — 대기 화면 카운트다운을 매번 처음부터 돌리는 키
  final int attempt;

  bool get canSendTest => hasReadSettings && blockers.isEmpty;

  IosVibrationCheckState copyWith({
    IosVibrationCheckStep? step,
    Set<VibrationCheckBlocker>? blockers,
    bool? hasReadSettings,
    bool? isScheduleFailed,
    int? attempt,
  }) => IosVibrationCheckState(
    step: step ?? this.step,
    blockers: blockers ?? this.blockers,
    hasReadSettings: hasReadSettings ?? this.hasReadSettings,
    isScheduleFailed: isScheduleFailed ?? this.isScheduleFailed,
    attempt: attempt ?? this.attempt,
  );
}
