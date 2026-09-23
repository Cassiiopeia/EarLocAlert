/// 한글 낱말 안에서 줄이 끊기지 않게 한다 — CSS `word-break: keep-all` 대응
///
/// Flutter 는 한글 음절 사이를 전부 줄바꿈 가능 지점으로 본다. 그래서
/// "알립니다" 가 "알립니 / 다" 로, "않습니다" 가 "않습 / 니다" 로 쪼개졌다
/// (이슈 #153 QA — 기본 글자 크기의 온보딩에서도 보였다). 이 옵션을
/// 텍스트 스타일로 켤 방법이 없어, 낱말 안 글자 사이에 **줄바꿈 금지
/// 문자(U+2060 WORD JOINER)** 를 넣어 띄어쓰기에서만 줄이 바뀌게 한다.
///
/// - 폭이 0 이라 보이지 않고, 스크린리더도 읽지 않는다
/// - 한 낱말이 줄보다 길면 엔진이 그래도 끊는다 — 넘치지 않는다
/// - **화면에 그릴 때만 쓴다.** 저장·로그·비교에 쓰면 원문과 달라진다
extension KeepAll on String {
  static const _wordJoiner = '\u2060';

  /// 공백이 아닌 글자 사이마다 줄바꿈 금지 문자를 넣는다
  String get keepAll {
    if (isEmpty) return this;
    final buffer = StringBuffer();
    final runes = this.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      final current = runes[i];
      buffer.writeCharCode(current);
      if (i + 1 >= runes.length) continue;
      final next = runes[i + 1];
      if (_isSpace(current) || _isSpace(next)) continue;
      // 이모지 조합(👨‍👩‍👧, 👍🏻, 1️⃣)은 사이에 글자가 끼면 낱개로 흩어진다 —
      // 사용자가 장소명에 쓸 수 있다
      if (_isJoining(current) || _isJoining(next)) continue;
      buffer.write(_wordJoiner);
    }
    return buffer.toString();
  }

  static bool _isSpace(int rune) => String.fromCharCode(rune).trim().isEmpty;

  /// 앞뒤 글자와 한 덩어리로 그려져야 하는 문자
  static bool _isJoining(int rune) =>
      rune == 0x200D || // ZWJ
      (rune >= 0xFE00 && rune <= 0xFE0F) || // 변형 선택자
      rune == 0x20E3 || // 키캡
      (rune >= 0x1F3FB && rune <= 0x1F3FF) || // 피부색
      (rune >= 0x0300 && rune <= 0x036F); // 결합 부호
}
