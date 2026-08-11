import 'dart:io';

import '../domain/permission_gate.dart';

/// 온보딩 단계별 안내 문구
///
/// **요청하기 전에 이유를 말한다** (docs/06-UX.md). 시스템 다이얼로그를
/// 바로 띄우지 않고 앱이 직접 그린 설명을 먼저 보여준다.
///
/// 이 문구는 그대로 **스토어 심사 자료가 된다** (docs/09-RELEASE.md).
class PermissionCopy {
  const PermissionCopy({
    required this.title,
    required this.body,
    required this.actionLabel,
    this.footnote,
  });

  final String title;
  final String body;
  final String actionLabel;

  /// 위치를 전송하지 않는다는 사실 — 사용자가 "항상 위치"를 꺼리는
  /// 진짜 이유는 추적당하는 것이다. 사실을 말하는 것이 가장 효과적이다.
  final String? footnote;

  static PermissionCopy forStep(OnboardingStep step) => switch (step) {
    OnboardingStep.requestLocation => const PermissionCopy(
      title: '위치 권한이 필요합니다',
      body: '알림을 걸어둘 장소를 지도에서 고르고, 지금 어디쯤인지 표시하기 위해 사용합니다.',
      actionLabel: '계속',
      footnote: '위치 정보는 기기에만 저장되며 어디에도 전송되지 않습니다.',
    ),
    OnboardingStep.requestBackgroundLocation => PermissionCopy(
      title: '항상 허용이 필요합니다',
      body:
          '앱을 열어두지 않아도 도착과 출발을 알려드리려면 백그라운드에서 위치를 확인해야 합니다.\n\n'
          '이 권한이 없으면 화면을 계속 보고 있어야 해서, 알림 자체가 의미를 잃습니다.',
      actionLabel: Platform.isAndroid ? '설정에서 항상 허용' : '계속',
      footnote: Platform.isAndroid
          ? '설정 화면에서 위치 권한을 "항상 허용"으로 바꿔주세요.\n'
                '위치 정보는 기기에만 저장되며 어디에도 전송되지 않습니다.'
          : '위치 정보는 기기에만 저장되며 어디에도 전송되지 않습니다.',
    ),
    OnboardingStep.requestNotification => const PermissionCopy(
      title: '알림 권한이 필요합니다',
      body: '도착하거나 떠날 때 알려드리기 위해 사용합니다.',
      actionLabel: '계속',
    ),
    // 이슈 #74 — 이 셋이 없으면 앱을 열어두지 않은 동안 알림이 약해진다.
    // 필수는 아니지만 왜 필요한지를 증상으로 설명한다.
    OnboardingStep.requestAlertReliability => const PermissionCopy(
      title: '알림을 놓치지 않으려면',
      body:
          '휴대폰이 절전에 들어가거나 다른 앱을 보고 있으면, 도착 알림이 늦게 오거나 '
          '작은 알림으로만 지나갑니다.\n\n'
          '다음 세 가지를 켜면 화면을 덮는 알림이 해제할 때까지 계속됩니다.\n\n'
          '• 배터리 사용량 최적화 제외 — 절전 중에도 제때 알립니다\n'
          '• 다른 앱 위에 표시 — 영상을 보는 중에도 알림 화면이 뜹니다\n'
          '• 전체 화면 알림 — 화면이 꺼져 있어도 깨웁니다',
      actionLabel: '세 가지 모두 켜기',
      // 이전 문구는 "건너뛰어도 그대로 동작한다"였는데 사실과 다르다
      // (이슈 #84). 이 권한들이 없으면 알림 화면이 저절로 뜨지 않아,
      // 진동이 울리는데 끄려면 알림을 눌러 앱을 열어야 한다. 대가를
      // 숨기면 사용자는 나중에 오작동으로 받아들인다.
      footnote:
          '설정 화면이 차례로 열립니다. 건너뛰면 알림 화면이 저절로 뜨지 않아, 진동을 끄려면 알림을 눌러 앱을 열어야 합니다.',
    ),
    OnboardingStep.openSettings => const PermissionCopy(
      title: '설정에서 권한을 켜주세요',
      body: '권한이 거부된 상태라 앱에서 다시 요청할 수 없습니다. 설정 화면에서 직접 허용해주세요.',
      actionLabel: '설정 열기',
    ),
    OnboardingStep.done => const PermissionCopy(
      title: '준비되었습니다',
      body: '이제 장소를 등록하면 도착과 출발을 알려드립니다.',
      actionLabel: '시작하기',
    ),
  };
}
