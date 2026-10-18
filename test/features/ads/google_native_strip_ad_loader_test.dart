import 'package:ear_loc_alert/features/ads/data/google_native_strip_ad_loader.dart';
import 'package:ear_loc_alert/features/ads/domain/native_strip_ad_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 네이티브 띠 로더 (이슈 #283)
///
/// 실제 SDK 요청은 플랫폼 채널이라 단위 테스트에서 돌릴 수 없다. 요청 전에
/// 갈리는 분기와 네이티브로 넘기는 옵션 모양만 고정한다.
void main() {
  const colors = NativeStripAdColors(
    background: 0xFF111111,
    headline: 0xFF222222,
    callToAction: 0xFF333333,
    badgeBackground: 0xFF444444,
    badgeText: 0xFF555555,
  );

  test('운영 단위 ID 가 비어 있으면 광고를 요청하지 않고 null 이다', () async {
    final loader = GoogleNativeStripAdLoader(resolveUnitId: () => '');

    expect(await loader.load(colors), isNull);
  });

  test('네이티브 팩토리 옵션은 색 다섯 개와 AD 배지 문구를 담는다', () {
    final options = GoogleNativeStripAdLoader.customOptionsOf(colors);

    expect(options, {
      'backgroundColor': 0xFF111111,
      'headlineColor': 0xFF222222,
      'callToActionColor': 0xFF333333,
      'badgeBackgroundColor': 0xFF444444,
      'badgeTextColor': 0xFF555555,
      'badgeLabel': 'AD',
    });
  });

  test('팩토리 ID 는 네이티브 등록 이름과 같다', () {
    // MainActivity.kt · AppDelegate.swift 가 이 이름으로 등록한다
    expect(GoogleNativeStripAdLoader.factoryId, 'earLocAlertStrip');
  });
}
