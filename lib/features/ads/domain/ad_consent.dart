import '../../../core/diagnostics/diagnostics.dart';

/// 광고 동의 (이슈 #166)
///
/// **유럽 경제 지역과 영국 사용자에게는 광고를 요청하기 전에 동의를 받아야
/// 한다** — AdMob 정책이다. 앱을 한국 밖에서 쓰게 되면(#163) 필수다. 동의 없이
/// 광고를 요청하면 계정이 위험해진다.
///
/// **이 인터페이스의 메서드는 예외를 던지지 않는다.** 광고는 부가 기능이고
/// 동의 실패가 알림 흐름에 영향을 주면 안 된다
/// (docs/02-ARCHITECTURE.md 규칙 4).
abstract interface class AdConsent {
  /// 동의 정보를 갱신하고, 필요하면 동의 화면을 띄운다.
  ///
  /// 동의가 필요 없는 지역이거나 AdMob 콘솔에 동의 메시지가 없으면 아무것도
  /// 보이지 않는다.
  Future<void> gather();

  /// 지금 광고를 요청해도 되는가.
  ///
  /// 동의를 받았거나 필요 없는 지역이면 `true`. 동의 정보를 아직 못 읽었으면
  /// `false` 다 — **모르면 요청하지 않는다.**
  Future<bool> canRequestAds();

  /// 사용자가 동의 선택을 다시 열 수 있어야 하는 지역인가 (이슈 #188).
  ///
  /// 유럽 경제 지역과 영국에서 동의 화면을 거친 사용자는 언제든 선택을
  /// 바꿀 수 있어야 한다. **모르면 `false`** — 없는 항목을 보여주는 것보다 낫다.
  Future<bool> isPrivacyOptionsRequired();

  /// 동의 선택을 다시 여는 화면을 띄운다. 실패해도 예외를 던지지 않는다.
  Future<void> showPrivacyOptions();
}

/// 동의 화면을 띄울 수 있을 때만 띄운다 (이슈 #166)
///
/// **알림 화면 위에 동의 화면을 겹치지 않는다.** 알림이 울려 앱이 뜬 순간에
/// 동의 화면이 올라오면 해제 버튼이 가려진다. 해제가 가장 중요한 동작이고
/// 광고를 알림 화면에 겹치지 않는다는 규칙(CLAUDE.md 규칙 3)과 같은 이유다.
/// 그 경우에는 건너뛰고 다음 앱 실행 때 받는다.
class AdConsentGate {
  const AdConsentGate(this._consent);

  final AdConsent _consent;

  /// 알림이 울리는 중이 아닐 때만 동의를 받는다. 받았으면 `true`.
  Future<bool> gatherWhenIdle({required bool Function() alertActive}) async {
    if (alertActive()) {
      Diagnostics.log('ads', 'consent gathering skipped reason=alert_active');
      return false;
    }
    await _consent.gather();
    return true;
  }
}
