import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/features/ads/domain/ad_consent.dart';

/// 광고 동의 (이슈 #166) — 알림 화면 위에 동의 화면을 겹치지 않는다
class _FakeConsent implements AdConsent {
  int gathered = 0;

  @override
  Future<void> gather() async => gathered++;

  @override
  Future<bool> canRequestAds() async => true;
}

void main() {
  test('알림이 울리는 중이 아니면 동의를 받는다', () async {
    final consent = _FakeConsent();
    final gathered = await AdConsentGate(
      consent,
    ).gatherWhenIdle(alertActive: () => false);

    expect(gathered, isTrue);
    expect(consent.gathered, 1);
  });

  test('알림이 울리는 중이면 동의 화면을 띄우지 않는다 — 해제 버튼이 가려진다', () async {
    final consent = _FakeConsent();
    final gathered = await AdConsentGate(
      consent,
    ).gatherWhenIdle(alertActive: () => true);

    expect(gathered, isFalse);
    expect(consent.gathered, 0);
  });
}
