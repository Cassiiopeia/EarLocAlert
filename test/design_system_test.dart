import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 디자인 시스템 규칙 (docs/06-UX.md · 이슈 #153)
///
/// **문서만으로는 이미 한 번 실패했다.** `버튼 | 하단, 전체 폭, pill 형태`
/// 가 `06-UX.md` 에 적혀 있는데도 알림음 시트가 그것을 어긴 채 배포됐다.
/// 규칙은 적어두는 것으로 지켜지지 않는다 — 여기서 센다.
///
/// **소스를 읽는 테스트인 이유** — 위젯 테스트로는 "앱 어디에도 이 패턴이
/// 없다"를 셀 수 없다. 화면마다 테스트를 쓰면 새 화면이 생겼을 때 또 빠지는데,
/// 규칙이 깨지는 자리는 언제나 "새로 만든 화면"이다.
void main() {
  final presentation = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => f.path.contains('/presentation/'))
      .toList();

  setUpAll(() {
    expect(presentation, isNotEmpty, reason: '화면 파일을 하나도 못 찾았다면 경로 규칙이 바뀐 것이다');
  });

  group('주 액션은 하단 한 자리뿐이다', () {
    test('한 화면에 FilledButton 이 둘 이상이면 위계가 갈린다', () {
      final offenders = <String>[];
      for (final file in presentation) {
        // **파일이 아니라 위젯 클래스 단위로 센다.** 한 파일에 정상 화면과
        // 오류 화면이 같이 있는 것은 흔하고, 그 둘은 동시에 뜨지 않는다.
        // 파일로 세면 멀쩡한 코드를 위반으로 잡는다.
        for (final entry in _widgetClasses(file.readAsStringSync()).entries) {
          // `FilledButton.styleFrom(` 은 버튼이 아니라 스타일이다
          final count = RegExp(
            r'\bFilledButton(\.icon)?\(',
          ).allMatches(entry.value).length;
          if (count > 1) {
            offenders.add('${file.path} → ${entry.key} ($count개)');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '하단 주 버튼은 "안 누르면 목적이 달성되지 않는 동작" 하나뿐이다.\n'
            '둘을 두면 사용자가 무엇을 눌러야 하는지 매번 읽어야 한다.\n'
            '해당 파일: $offenders',
      );
    });

    test('보조 동작이 주 버튼 자리를 차지하지 않는다', () {
      // 주 버튼에 오면 안 되는 낱말 — 안 해도 화면의 목적은 달성된다
      const secondaryWords = ['추가', '미리듣기', '내보내기', '삭제'];
      final offenders = <String>[];

      for (final file in presentation) {
        final source = file.readAsStringSync();
        for (final match in RegExp(
          r'FilledButton[^;]{0,400}?;',
          dotAll: true,
        ).allMatches(source)) {
          final block = match.group(0)!;
          for (final word in secondaryWords) {
            if (block.contains("'$word") || block.contains("$word'")) {
              offenders.add('${file.path}: "$word"');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '보조 동작은 OutlinedButton 이나 목록 안에 둔다.\n'
            '해당: $offenders',
      );
    });
  });

  group('용어 사전', () {
    test('목적어 없는 라벨을 쓰지 않는다', () {
      // 무엇이 기본 제공인지 말하지 않으면 옆의 "내 음원" 과 짝이 안 맞는다
      const banned = {'기본 제공': '기본 알림음'};
      final offenders = <String>[];

      for (final file in presentation) {
        final source = file.readAsStringSync();
        for (final entry in banned.entries) {
          if (source.contains("'${entry.key}'")) {
            offenders.add('${file.path}: "${entry.key}" → "${entry.value}"');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('같은 기능은 같은 자리', () {
    test('지도 SDK 의 내 위치 버튼을 쓰지 않는다', () {
      // SDK 버튼은 우상단 고정이라 검색창·상태 알약과 부딪힌다 (#98·#152)
      final offenders = presentation
          .where(
            (f) =>
                f.readAsStringSync().contains('myLocationButtonEnabled: true'),
          )
          .map((f) => f.path)
          .toList();
      expect(
        offenders,
        isEmpty,
        reason: '오른쪽 스택의 커스텀 버튼으로 통일한다 (#155). 해당: $offenders',
      );
    });

    test('중앙 고정 핀이 있는 지도에는 padding 을 주지 않는다', () {
      // padding 은 카메라 중심을 옮기는데 핀은 그것을 모른다 — 이슈 #152 가
      // 그렇게 났다. 둘이 한 파일에 같이 있으면 어긋날 수 있다.
      final offenders = <String>[];
      for (final file in presentation) {
        final source = file.readAsStringSync();
        final hasCenterPin =
            source.contains('중앙 고정 핀') ||
            source.contains('Icons.place_outlined');
        final hasMapPadding = RegExp(
          r'GoogleMap\([^;]*?\bpadding:',
          dotAll: true,
        ).hasMatch(source);
        if (hasCenterPin && hasMapPadding) offenders.add(file.path);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'padding 이 정말 필요하면 핀도 같은 값만큼 함께 옮기고 이 테스트를\n'
            '그 관계를 세는 것으로 바꾼다. 지금처럼 각자 두면 또 어긋난다.\n'
            '해당: $offenders',
      );
    });
  });

  test('한글 문장은 낱말 안에서 끊기지 않게 그린다', () {
    // Flutter 는 한글 음절 사이를 전부 줄바꿈 지점으로 봐 "알립니 / 다" 로
    // 쪼갰다 (이슈 #153 QA). 문장을 Text 에 넣을 때는 `.keepAll` 을
    // 거친다 — 새 문구를 추가하는 자리가 늘 빠지는 자리다.
    //
    // 여러 줄이 될 수 있는 설명문만 센다 — 15자 이상에 세 낱말 이상.
    // "알림 끄기"·"첫 장소를 등록해보세요" 같은 라벨·제목은 한 줄에 든다
    final literal = RegExp(r"'([^'\n]*)'");
    bool isSentence(String text) =>
        RegExp('[가-힣]').hasMatch(text) &&
        ' '.allMatches(text).length >= 2 &&
        text.replaceAll(RegExp(r'\$(\{[^}]*\}|\w+)'), '').length >= 15;
    final offenders = <String>[];
    for (final file in presentation) {
      final source = file.readAsStringSync();
      for (final call in _calls(source, 'Text')) {
        final first = _firstArgument(call.args);
        final texts = literal.allMatches(first).map((m) => m.group(1)!);
        if (!texts.any(isSentence)) continue;
        if (first.contains('.keepAll')) continue;
        offenders.add('${file.path}:${call.line} ${first.trim()}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: "문장 뒤에 .keepAll 을 붙인다 ('…'.keepAll).\n해당: $offenders",
    );
  });

  group('아이콘은 한 규격으로', () {
    // 화면 전체(lib) 를 본다 — app 계층에도 아이콘이 있다
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .toList();

    test('아이콘 크기는 AppIconSize 토큰만 쓴다', () {
      // 14·16·18·20·22·24·56·64 여덟 가지가 섞여 같은 꺾쇠가 화면마다
      // 14·20·24 로 달랐다 (이슈 #155 QA).
      //
      // 지도 위 중앙 핀(_pinSize)은 아이콘이 아니라 조준점이라 뺀다 —
      // 크기가 저장 좌표 정렬에 묶여 있어 토큰으로 바꾸면 안 된다 (#152)
      const exempt = {'_pinSize'};
      final offenders = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        for (final call in _calls(source, 'Icon')) {
          final size = RegExp(r'\bsize:\s*([\w.]+)').firstMatch(call.args);
          if (size == null) continue; // 기본값(24) = standard
          final value = size.group(1)!;
          if (value.startsWith('AppIconSize.') || exempt.contains(value)) {
            continue;
          }
          offenders.add('${file.path}:${call.line} size: $value');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '글자 옆은 AppIconSize.inline(18), 버튼·목록은 standard(24), '
            '화면 중심 상징은 hero(56).\n해당: $offenders',
      );
    });

    test('Material 아이콘은 _outlined 변형만 쓴다', () {
      // docs/06-UX.md "아이콘 — Material outlined 로 통일" 이 적혀 있는데도
      // chevron_right·close·warning_amber_rounded 가 섞여 있었다
      final offenders = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        for (final match in RegExp(r'Icons\.(\w+)').allMatches(source)) {
          final name = match.group(1)!;
          if (name.endsWith('_outlined')) continue;
          final line = source.substring(0, match.start).split('\n').length;
          offenders.add('${file.path}:$line Icons.$name');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'filled·rounded·outline(구 이름)을 섞지 않는다.\n해당: $offenders',
      );
    });
  });
}

/// 첫 번째 위치 인자 — 최상위 쉼표 앞까지 (괄호·문자열 안 쉼표는 건너뛴다)
String _firstArgument(String args) {
  var depth = 0;
  String? quote;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if (quote != null) {
      if (c == '\\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      depth--;
    } else if (c == ',' && depth == 0) {
      return args.substring(0, i);
    }
  }
  return args;
}

/// `name(` 호출을 괄호 짝까지 잘라낸다 — 인자가 여러 줄에 걸쳐도 잡는다
List<({String args, int line})> _calls(String source, String name) {
  final result = <({String args, int line})>[];
  for (final match in RegExp('\\b$name\\(').allMatches(source)) {
    var depth = 1;
    var i = match.end;
    while (depth > 0 && i < source.length) {
      final c = source[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      i++;
    }
    result.add((
      args: source.substring(match.end, i - 1),
      line: source.substring(0, match.start).split('\n').length,
    ));
  }
  return result;
}

/// 소스를 위젯 클래스 단위로 쪼갠다.
///
/// 한 파일에 화면과 그 화면이 쓰는 작은 위젯들이 함께 사는 것이 이 레포의
/// 관례다. 규칙은 "한 화면에" 걸리는 것이므로 클래스가 단위여야 한다.
Map<String, String> _widgetClasses(String source) {
  final starts = RegExp(
    r'^class\s+(\w+)',
    multiLine: true,
  ).allMatches(source).toList();
  if (starts.isEmpty) return {'(파일 전체)': source};

  final result = <String, String>{};
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1].start : source.length;
    result[starts[i].group(1)!] = source.substring(starts[i].start, end);
  }
  return result;
}
