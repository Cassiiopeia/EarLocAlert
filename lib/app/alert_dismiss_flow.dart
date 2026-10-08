import 'dart:async';

import '../core/diagnostics/diagnostics.dart';
import '../features/alert/domain/alert_session.dart';

/// 알림을 끈 뒤의 흐름 (이슈 #233, 결정 056)
///
/// **해제 완료 화면을 없앴다.** 끈 뒤에 "알림을 껐습니다"와 확인 버튼 하나뿐인
/// 화면을 한 번 더 눌러야 홈에 닿았다 — 버스에서 급하게 끈 사용자에게 버튼이
/// 하나 더 생긴 것이다. 이제 끄면 곧장 홈이고, 같은 문구는 토스트로 보인다.
///
/// 그 화면은 전면광고를 알림 화면과 떼어 두는 칸막이이기도 했다. 칸막이를
/// 지키는 규칙은 여기서 그대로 이어진다:
/// 1. **해제가 먼저다** — 진동·소리가 멈춘 뒤에 화면을 옮긴다
/// 2. **광고를 기다리지 않는다** — 광고는 `unawaited` 로만 시도한다 (규칙 4)
/// 3. **홈이 그려진 뒤, 잠깐 쉬고** 시도한다 — 해제 버튼을 누르던 엄지가 그대로
///    광고를 누르지 않게 한다 (docs/07-MONETIZATION.md)
/// 4. 쉬는 사이 **다른 알림이 울리기 시작했으면 내지 않는다** — 알림 화면 위에
///    광고가 겹치면 계정 정지 사유다 (CLAUDE.md 규칙 3)
class AlertDismissFlow {
  AlertDismissFlow({
    required Future<AlertSession?> Function() dismiss,
    required bool Function() isRinging,
    required void Function() goHome,
    required void Function() returnToSettings,
    required void Function() showDismissedToast,
    required Future<void> Function() tryShowAd,
    this.adDelay = defaultAdDelay,
  }) : _dismiss = dismiss,
       _isRinging = isRinging,
       _goHome = goHome,
       _returnToSettings = returnToSettings,
       _showDismissedToast = showDismissedToast,
       _tryShowAd = tryShowAd;

  /// 홈이 뜬 뒤 광고까지 쉬는 시간. 해제 버튼에서 손가락이 떨어질 만큼이면 된다
  static const defaultAdDelay = Duration(milliseconds: 700);

  final Future<AlertSession?> Function() _dismiss;
  final bool Function() _isRinging;
  final void Function() _goHome;
  final void Function() _returnToSettings;
  final void Function() _showDismissedToast;
  final Future<void> Function() _tryShowAd;
  final Duration adDelay;

  /// 해제 버튼을 눌렀다. [fromPreview] 는 설정의 미리보기에서 시작한 세션인가.
  ///
  /// 반환되는 순간 진동·소리는 이미 멈춰 있고 화면 전환도 끝났다. 광고는 이
  /// Future 와 무관하게 뒤에서 시도된다.
  Future<void> run({required bool fromPreview}) async {
    // 1) 해제가 먼저다. 광고와 무관하게 여기서 진동·소리가 멈춘다
    final dismissed = await _dismiss();

    // 대기 중이던 다른 장소 알림이 이어서 울리면 알림 화면에 머문다
    if (_isRinging()) return;

    _goHome();
    if (dismissed == null) return;

    // 미리보기는 설정에서 시작했으니 설정으로 돌려보낸다 (이슈 #229)
    if (fromPreview) {
      Diagnostics.log('alert', 'preview dismissed return=settings');
      _returnToSettings();
    }
    Diagnostics.log(
      'alert',
      'dismissed, returned home place=${dismissed.placeName} '
          'ad_delay_ms=${adDelay.inMilliseconds}',
    );
    _showDismissedToast();

    // 2) 광고는 기다리지 않는다 (docs/02-ARCHITECTURE.md 규칙 4)
    unawaited(_showAdLater());
  }

  Future<void> _showAdLater() async {
    await Future<void>.delayed(adDelay);
    if (_isRinging()) {
      Diagnostics.log('ads', 'interstitial skipped (reason=alert_active)');
      return;
    }
    try {
      await _tryShowAd();
    } on Object catch (error) {
      // 광고는 부가 기능이다 — 실패해도 사용자 흐름에 영향이 없다
      Diagnostics.log('ads', 'interstitial attempt failed $error');
    }
  }
}
