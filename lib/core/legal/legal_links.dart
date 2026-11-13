/// 이용약관·개인정보처리방침 주소 (이슈 #188)
///
/// 문서는 소개 사이트(`gh-pages` 브랜치 생성기 > earlocalert.suhsaechan.kr, #365)에 있다.
/// 옛 github.io 주소는 같은 경로의 새 주소로 넘긴다 — 이전 버전 앱 링크도 유지. **한국어 문서와 영어 문서만 있고**
/// 중국어·일본어는 영어 문서로 보낸다 — 번역본이 생기면 여기에 분기를 더한다.
/// 앱 안에 문서를 넣지 않는 이유: 방침을 고치려고 앱을 다시 배포하지 않게 하기 위해서다.
abstract final class LegalLinks {
  static const _base = 'https://earlocalert.suhsaechan.kr';

  static Uri terms(String languageCode) => Uri.parse(
    '$_base/${_isKorean(languageCode) ? 'terms' : 'terms-en'}.html',
  );

  static Uri privacy(String languageCode) => Uri.parse(
    '$_base/${_isKorean(languageCode) ? 'privacy' : 'privacy-en'}.html',
  );

  static bool _isKorean(String languageCode) => languageCode == 'ko';
}
