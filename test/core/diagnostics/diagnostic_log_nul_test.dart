import 'dart:convert';

import 'package:ear_loc_alert/core/diagnostics/diagnostic_log_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 기록 중 종료로 생긴 NUL 바이트가 복사·내보내기를 끊지 않는다 (이슈 #239)
void main() {
  test('NUL 덩어리는 표식 줄로 바뀌고 뒤 기록이 살아남는다', () {
    final bytes = [
      ...utf8.encode(
        '2026-10-08T09:08:23.090827Z [engine] precise decision pl',
      ),
      ...List.filled(512, 0),
      ...utf8.encode('2026-10-08T10:00:00.000000Z [app] app start\n'),
    ];

    final text = DiagnosticLogReader.decodeTolerant(bytes);

    expect(text.contains('\u0000'), isFalse);
    expect(text, contains(DiagnosticLogReader.nulMarker));
    expect(text, contains('bytes=512'));
    final lines = DiagnosticLogReader.linesOf(text);
    expect(lines.first, '2026-10-08T10:00:00.000000Z [app] app start');
  });

  test('병합 뒤에도 끊긴 지점 이후 기록이 시각순으로 남는다', () {
    final app = DiagnosticLogReader.decodeTolerant([
      ...utf8.encode('2026-10-08T09:08:23.000000Z [engine] cut'),
      0,
      0,
      0,
      ...utf8.encode('2026-10-08T10:00:00.000000Z [app] app start\n'),
    ]);
    const native = '2026-10-08T10:00:01.000Z [watch] ios watch launch\n';

    final merged = DiagnosticLogReader.mergeByTimestamp([app, native]);

    expect(merged.contains('\u0000'), isFalse);
    expect(
      merged.trim().split('\n').last,
      contains('[watch] ios watch launch'),
    );
  });

  test('NUL 이 없으면 그대로 둔다', () {
    const text = '2026-10-08T10:00:00.000000Z [app] ok\n';
    expect(DiagnosticLogReader.stripNulRuns(text), text);
  });
}
