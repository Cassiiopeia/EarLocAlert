import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 화면 문자열을 코드에 한글로 박지 않는다 (이슈 #163, 결정 035 방식)
///
/// **문서는 이미 한 번 실패했다.** `docs/04-CONVENTIONS.md` 는 처음부터 "문자열은
/// 하드코딩하지 않는다"고 적었지만 코드에는 l10n 이 없었다. 규칙은 적어두는
/// 것으로 지켜지지 않는다 — 여기서 센다.
///
/// 잡는 것: `lib/` 의 한글이 든 문자열 리터럴. **주석은 제외**하고, 생성 파일과
/// 번역 파일 자체는 제외한다. 로그는 영어이므로(결정 040) 예외가 없다.
///
/// 새 화면에서 문구를 추가하는 자리가 늘 빠지는 자리다 — 새 파일이 생겨도
/// 자동으로 검사 대상이 된다.
void main() {
  test('lib 의 문자열 리터럴에 한글이 없다 — 화면 문구는 번역 파일에 둔다', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'))
        .where((f) => !f.path.contains('/l10n/'))
        .toList();
    expect(files, isNotEmpty, reason: '경로 규칙이 바뀌었다');

    final literal = RegExp(r"""['"][^'"\n]*[가-힣][^'"\n]*['"]""");
    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('/*')) {
          continue;
        }
        // 줄 끝 주석을 떼고 본다
        final code = lines[i].replaceFirst(RegExp(r'//.*$'), '');
        if (literal.hasMatch(code)) {
          offenders.add(
            '${file.path}:${i + 1} ${trimmed.length > 90 ? '${trimmed.substring(0, 90)}…' : trimmed}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '화면 문구는 lib/core/l10n/arb 의 번역 파일에 두고 context.l10n.키 로 읽는다.\n'
          '로그는 영어로 쓴다(결정 040).\n해당:\n${offenders.join('\n')}',
    );
  });
}
