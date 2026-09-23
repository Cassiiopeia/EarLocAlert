import 'package:ear_loc_alert/core/text/keep_all.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 한글 낱말 안 줄바꿈 금지 (이슈 #153 QA)
void main() {
  const j = '\u2060';

  test('낱말 안 글자 사이에만 넣고 띄어쓰기는 그대로 둔다', () {
    expect('소리가 납니다'.keepAll, '소$j리$j가 납$j니$j다');
  });

  test('줄바꿈 문자 앞뒤에는 넣지 않는다', () {
    expect('가나\n다라'.keepAll, '가$j나\n다$j라');
  });

  test('빈 문자열·한 글자는 그대로다', () {
    expect(''.keepAll, '');
    expect('가'.keepAll, '가');
  });

  test('이모지 조합은 쪼개지 않는다', () {
    const family = '👨‍👩‍👧';
    expect(family.keepAll, family);
    expect('👍🏻'.keepAll, '👍🏻');
  });

  testWidgets('낱말 중간이 아니라 띄어쓰기에서 줄이 바뀐다', (tester) async {
    // 폭을 좁혀 두 줄이 되게 한다. 테스트 글꼴은 글자 폭이 글자 크기와 같다
    const text = '알림이 울리면 알립니다';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 150,
            child: Text(text.keepAll, style: const TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    final lines = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.keepAll.length),
        )
        .map((box) => box.top)
        .toSet();
    expect(lines.length, greaterThan(1), reason: '두 줄이 되어야 검사가 의미 있다');

    // 각 낱말의 첫 글자와 끝 글자가 같은 줄에 있어야 한다
    final joined = text.keepAll;
    var offset = 0;
    for (final word in joined.split(' ')) {
      final first = paragraph.getOffsetForCaret(
        TextPosition(offset: offset),
        Rect.zero,
      );
      final last = paragraph.getOffsetForCaret(
        TextPosition(offset: offset + word.length - 1),
        Rect.zero,
      );
      expect(first.dy, last.dy, reason: '"$word" 가 두 줄로 쪼개졌다');
      offset += word.length + 1;
    }
  });
}
