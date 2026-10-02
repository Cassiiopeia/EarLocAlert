import 'package:ear_loc_alert/core/legal/legal_links.dart';
import 'package:flutter_test/flutter_test.dart';

/// 약관·방침 주소 (이슈 #188)
void main() {
  test('한국어는 한국어 문서로 간다', () {
    expect(LegalLinks.terms('ko').path, endsWith('/terms.html'));
    expect(LegalLinks.privacy('ko').path, endsWith('/privacy.html'));
  });

  test('영어, 중국어, 일본어는 영어 문서로 간다', () {
    for (final code in ['en', 'zh', 'ja']) {
      expect(LegalLinks.terms(code).path, endsWith('/terms-en.html'));
      expect(LegalLinks.privacy(code).path, endsWith('/privacy-en.html'));
    }
  });

  test('모든 주소가 https 다', () {
    // 외부 브라우저로 여는 링크가 평문이면 심사에서 지적된다
    expect(LegalLinks.terms('ko').scheme, 'https');
    expect(LegalLinks.privacy('en').scheme, 'https');
  });
}
