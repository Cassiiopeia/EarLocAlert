/// 이용약관·개인정보처리방침 주소 (이슈 #188)
///
/// 문서는 `gh-pages` 브랜치에 있다. **한국어 문서와 영어 문서만 있고**
/// 중국어·일본어는 영어 문서로 보낸다 — 번역본이 생기면 여기에 분기를 더한다.
/// 앱 안에 문서를 넣지 않는 이유: 방침을 고치려고 앱을 다시 배포하지 않게 하기 위해서다.
abstract final class LegalLinks {
  static const _base = 'https://cassiiopeia.github.io/EarLocAlert';

  static Uri terms(String languageCode) => Uri.parse(
    '$_base/${_isKorean(languageCode) ? 'terms' : 'terms-en'}.html',
  );

  static Uri privacy(String languageCode) => Uri.parse(
    '$_base/${_isKorean(languageCode) ? 'privacy' : 'privacy-en'}.html',
  );

  static bool _isKorean(String languageCode) => languageCode == 'ko';
}
