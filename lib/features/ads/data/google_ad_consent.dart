import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/ad_consent.dart';

/// Google 사용자 메시지 플랫폼(UMP) 기반 동의 (이슈 #166)
///
/// AdMob 콘솔에 동의 메시지를 만들어 두어야 화면이 뜬다 — **콘솔에 없으면
/// 이 코드는 아무 화면도 띄우지 않고 지나간다.** 메시지 설정은 사용자 작업이다
/// (docs/07-MONETIZATION.md).
class GoogleAdConsent implements AdConsent {
  const GoogleAdConsent();

  @override
  Future<void> gather() async {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            // 필요할 때만 화면을 띄우고, 사용자가 닫으면 끝난다
            await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                Diagnostics.log(
                  'ads',
                  'consent form failed code=${formError.errorCode} '
                      'message=${formError.message}',
                );
              }
              finish();
            });
          } on Object catch (error) {
            Diagnostics.log('ads', 'consent form threw $error');
            finish();
          }
        },
        (error) {
          Diagnostics.log(
            'ads',
            'consent info update failed code=${error.errorCode} '
                'message=${error.message}',
          );
          finish();
        },
      );
    } on Object catch (error) {
      Diagnostics.log('ads', 'consent gathering threw $error');
      finish();
    }
    await done.future;
  }

  @override
  Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } on Object catch (error) {
      // 모르면 요청하지 않는다
      Diagnostics.log('ads', 'canRequestAds failed $error');
      return false;
    }
  }
}
