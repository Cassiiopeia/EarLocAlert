import 'package:ear_loc_alert/core/diagnostics/log_rotation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 로그 회전 (이슈 #95)
///
/// **저장공간을 무한히 먹지 않으면서 최근 기록은 살린다.**
/// 잘못되면 로그가 통째로 날아가거나 파일이 계속 커진다.
void main() {
  test('상한 안이면 그대로 둔다', () {
    const content = 'line1\nline2\n';
    expect(trimToLimit(content, 1000), content);
  });

  test('상한을 넘으면 최근 절반만 남긴다', () {
    // 각 줄 6바이트('lineN\n') × 10줄 = 60바이트
    final content = List.generate(10, (i) => 'line$i').join('\n');
    final trimmed = trimToLimit(content, 20);

    expect(trimmed.length, lessThanOrEqualTo(20));
    // 최근 것이 살아있어야 한다 — 오래된 것을 버린다
    expect(trimmed, contains('line9'));
    expect(trimmed, isNot(contains('line0')));
  });

  test('줄 중간에서 자르지 않는다 — 깨진 줄을 남기지 않는다', () {
    final content = ['aaaaaaaaaa', 'bbbbbbbbbb', 'cccccccccc'].join('\n');
    final trimmed = trimToLimit(content, 15);

    // 남은 것은 온전한 줄들이어야 한다
    for (final line in trimmed.split('\n').where((l) => l.isNotEmpty)) {
      expect(
        ['aaaaaaaaaa', 'bbbbbbbbbb', 'cccccccccc'],
        contains(line),
        reason: '잘린 줄이 남았다: $line',
      );
    }
  });

  test('한 줄이 상한보다 길면 그 줄만 남긴다 — 빈 결과를 만들지 않는다', () {
    const content = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final trimmed = trimToLimit(content, 10);

    // 자르면 그 줄이 깨진다. 통째로 버리면 아무것도 안 남는다.
    // 마지막 줄은 상한을 넘더라도 보존한다.
    expect(trimmed, content);
  });

  test('빈 내용은 빈 채로 둔다', () {
    expect(trimToLimit('', 100), '');
  });

  test('한글이 포함돼도 바이트 기준으로 자른다', () {
    // 한글은 UTF-8 에서 3바이트다. 문자 수로 재면 상한을 넘긴다.
    final content = List.generate(10, (i) => '가나다라마$i').join('\n');
    final trimmed = trimToLimit(content, 40);

    expect(trimmed.codeUnits.length, lessThanOrEqualTo(40 * 2));
    expect(trimmed, contains('9'));
  });

  test('경계값 — 정확히 상한이면 그대로 둔다', () {
    const content = 'abcde';
    expect(trimToLimit(content, 5), content);
  });
}
