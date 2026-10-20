import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 기록 없이 삼키는 catch 동결 (CLAUDE.md 규칙 7 · 이슈 #284)
///
/// "예외를 삼키되 기록은 남긴다"를 소스에서 센다.
/// 통과 조건 4개: `Diagnostics.log(` · `rethrow` · `throw` · `completeError(`
///
/// 아래 목록은 **지금 남아 있는 정상 경로**(읽기 실패는 기본값, 채널 없는
/// 플랫폼, 로거 자신)의 파일별 건수다. 늘면 실패, 줄면 숫자를 내린다.
const _allowedSilentCatchCountByFile = {
  'lib/app/background/alert_watch_channel.dart': 2,
  'lib/app/background/ios_watch_channel.dart': 1,
  'lib/app/background/notification_action_handler.dart': 1,
  'lib/app/ios_alert_readiness.dart': 2,
  'lib/app/routes/settings_route.dart': 1,
  'lib/app/splash_overlay.dart': 1,
  'lib/core/config/build_info.dart': 2,
  'lib/core/config/dev_flag.dart': 1,
  'lib/core/database/alert_schedule_converter.dart': 1,
  // 로거 자신 — 기록 실패를 기록할 곳이 없음
  'lib/core/diagnostics/diagnostic_log_reader.dart': 3,
  'lib/core/diagnostics/diagnostics.dart': 1,
  'lib/core/diagnostics/file_diagnostic_logger.dart': 3,
  'lib/core/diagnostics/log_archive.dart': 2,
  'lib/core/map/map_reveal_cover.dart': 1,
  'lib/core/ui/foundation/app_theme_preference.dart': 1,
  'lib/features/alert/data/system_volume_channel.dart': 1,
  'lib/features/alert/domain/alert_strings.dart': 2,
  'lib/features/alert/presentation/vibration_intensity_sheet.dart': 2,
  // MissingPluginException — iOS·구버전 Android 는 채널 없음
  'lib/features/permission/data/full_screen_intent_channel.dart': 1,
  'lib/features/permission/data/prefs_reliability_prompt_store.dart': 3,
  'lib/features/places/data/maps_api_key_channel.dart': 1,
  'lib/features/places/domain/place_backup.dart': 1,
  'lib/features/places/presentation/place_form_screen.dart': 1,
  'lib/features/settings/data/prefs_watch_guide_store.dart': 2,
  'lib/features/sounds/data/file_picker_sound_source.dart': 1,
  'lib/features/sounds/data/just_audio_preview_player.dart': 1,
  'lib/features/sounds/data/just_audio_sound_probe.dart': 1,
};

/// catch 절 시작: `} on X catch (e) {` · `} on X {` · `} catch (e) {`
/// (앞의 `}` 로 extension `on X {` 와 구분)
final _catchClauseStart = RegExp(
  r'\}\s*(?:on\s+[\w<>?, ]+?\s*(?:catch\s*\([^)]*\))?|catch\s*\([^)]*\))\s*\{',
);

final _lineComment = RegExp(r'//.*');

final _recordsOrPropagates = RegExp(
  r'Diagnostics\.log\(|\brethrow\b|\bthrow\b|completeError\(',
);

/// 소스 > 기록·전파 없는 catch 블록 수
int _countSilentCatches(String source) {
  var count = 0;
  for (final match in _catchClauseStart.allMatches(source)) {
    // 중괄호 짝 맞추기로 블록 끝 찾기 (`${x}` 보간도 짝이 맞음)
    var index = match.end;
    var depth = 1;
    while (depth > 0 && index < source.length) {
      final char = source[index];
      if (char == '{') depth++;
      if (char == '}') depth--;
      index++;
    }
    // 주석 속 `throw`·`Diagnostics.log(` 는 기록이 아님
    final body = source
        .substring(match.end, index - 1)
        .replaceAll(_lineComment, '');
    if (!_recordsOrPropagates.hasMatch(body)) count++;
  }
  return count;
}

void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .where((f) => !f.path.endsWith('.freezed.dart'))
      .where((f) => !f.path.contains('/l10n/generated/'))
      .toList();

  test('기록 없이 삼키는 catch 가 파일별 허용 건수를 넘지 않는다', () {
    expect(sources, isNotEmpty);
    final exceeded = <String>[];
    for (final file in sources) {
      final path = file.path.replaceAll(r'\', '/');
      final count = _countSilentCatches(file.readAsStringSync());
      final allowed = _allowedSilentCatchCountByFile[path] ?? 0;
      if (count > allowed) exceeded.add('$path: $count (허용 $allowed)');
    }
    expect(
      exceeded,
      isEmpty,
      reason: 'catch 안에 Diagnostics.log 로 사유를 남긴다 (CLAUDE.md 규칙 7)',
    );
  });

  test('허용 목록이 실제보다 크지 않다 — 줄었으면 숫자를 내린다', () {
    final stale = <String>[];
    for (final entry in _allowedSilentCatchCountByFile.entries) {
      final file = File(entry.key);
      final count = file.existsSync()
          ? _countSilentCatches(file.readAsStringSync())
          : 0;
      if (count < entry.value) {
        stale.add('${entry.key}: $count (목록 ${entry.value})');
      }
    }
    expect(stale, isEmpty);
  });

  test('판정기가 로그 없는 catch 를 센다', () {
    expect(_countSilentCatches('try { a(); } on Object { b(); }'), 1);
    expect(_countSilentCatches('try { a(); } catch (e) { }'), 1);
    expect(
      _countSilentCatches(
        "try { a(); } on Object catch (e) { Diagnostics.log('t', 'x \${e}'); }",
      ),
      0,
    );
    expect(_countSilentCatches('extension X on Y { int get z => 1; }'), 0);
    expect(
      _countSilentCatches('try { a(); } on Object {\n // throw 안 함\n}'),
      1,
    );
  });
}
