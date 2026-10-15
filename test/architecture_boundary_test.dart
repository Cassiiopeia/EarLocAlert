import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 계층 경계 (docs/02-ARCHITECTURE.md 규칙 1~3, 아키텍처 검수 #276)
///
/// 문서에는 "lint 로 잡는다"고 적혀 있었지만 실제 규칙이 없어 위반이 쌓였다.
/// import 줄을 읽어 실제 대상 경로로 풀고 검사한다.
/// `as`·`show`·`hide` 가 붙은 import 와 export 도 잡는다 (#276 리뷰)
final _importPattern = RegExp(
  r'''^(?:import|export)\s+'([^']+)'[^;]*;''',
  multiLine: true,
);

/// `lib/` 기준 경로로 푼다. 패키지 밖 import 는 null
String? _resolve(File from, String target) {
  if (target.startsWith('package:ear_loc_alert/')) {
    return 'lib/${target.substring('package:ear_loc_alert/'.length)}';
  }
  if (target.startsWith('package:') || target.startsWith('dart:')) return null;
  return p.normalize(p.join(p.dirname(from.path), target));
}

Iterable<(File, String)> _importsUnder(String dir) sync* {
  final files = Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
  for (final file in files) {
    for (final match in _importPattern.allMatches(file.readAsStringSync())) {
      final resolved = _resolve(file, match.group(1)!);
      if (resolved != null) yield (file, resolved);
    }
  }
}

String? _featureOf(String path) {
  final parts = p.split(path);
  final i = parts.indexOf('features');
  return i >= 0 && i + 1 < parts.length ? parts[i + 1] : null;
}

void main() {
  test('feature 끼리 직접 import 하지 않는다 — app 계층이 조율한다 (규칙 1)', () {
    final offenders = [
      for (final (file, target) in _importsUnder('lib/features'))
        if (_featureOf(target) != null &&
            _featureOf(target) != _featureOf(file.path))
          '${file.path} → $target',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('core 는 features·app 을 모른다 (규칙 2)', () {
    final offenders = [
      for (final (file, target) in _importsUnder('lib/core'))
        if (target.startsWith('lib/features/') || target.startsWith('lib/app/'))
          '${file.path} → $target',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('presentation 은 data 구현을 모른다 — provider 조립 파일만 예외 (규칙 3)', () {
    // `*_provider(s).dart` 는 구현체를 인터페이스에 묶는 조립(DI) 코드다.
    // 화면 파일은 그 provider 를 통해 인터페이스만 받는다
    final assembly = RegExp(r'_providers?\.dart$');
    final offenders = [
      for (final (file, target) in _importsUnder('lib/features'))
        if (file.path.contains('/presentation/') &&
            target.contains('/data/') &&
            !assembly.hasMatch(file.path) &&
            !assembly.hasMatch(target))
          '${file.path} → $target',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('domain 은 data·presentation·Flutter 를 모른다', () {
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.contains('/domain/') && f.path.endsWith('.dart'));
    final offenders = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in _importPattern.allMatches(source)) {
        final raw = match.group(1)!;
        final resolved = _resolve(file, raw) ?? raw;
        if (resolved.contains('/data/') ||
            resolved.contains('/presentation/') ||
            // 판정 로직은 Flutter 없이 돌아야 한다 — 빌드 모드·플랫폼에 따라 값이
            // 바뀌는 설정은 core/config 에 둔다 (#278)
            raw.startsWith('package:flutter/')) {
          offenders.add('${file.path} → $raw');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
