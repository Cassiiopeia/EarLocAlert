import 'dart:io';

import 'package:ear_loc_alert/core/diagnostics/file_diagnostic_logger.dart';
import 'package:flutter_test/flutter_test.dart';

/// 파일 진단 로거 (이슈 #95)
///
/// 실제 파일 I/O 로 검증한다 — 회전·동시 기록이 목적이라 가짜로는
/// 의미가 없다.
void main() {
  late Directory tempDir;
  late File logFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('earloc_log_test');
    logFile = File('${tempDir.path}/diagnostic.log');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileDiagnosticLogger build({int maxBytes = 1024}) => FileDiagnosticLogger(
    file: logFile,
    maxBytes: maxBytes,
    clock: () => DateTime.utc(2026, 8, 14, 12, 30),
  );

  test('첫 기록이 파일을 만든다', () async {
    final logger = build();

    await logger.log('geofence', '진입 이벤트 수신');

    expect(logFile.existsSync(), isTrue);
    final content = await logger.readAll();
    expect(content, contains('[geofence]'));
    expect(content, contains('진입 이벤트 수신'));
    expect(content, contains('2026-08-14T12:30'));
  });

  test('여러 줄이 순서대로 쌓인다', () async {
    final logger = build();

    await logger.log('a', '첫째');
    await logger.log('b', '둘째');
    await logger.log('c', '셋째');

    final lines = (await logger.readAll()).trim().split('\n');
    expect(lines, hasLength(3));
    expect(lines[0], contains('첫째'));
    expect(lines[2], contains('셋째'));
  });

  test('상한을 넘으면 오래된 것부터 버린다', () async {
    // 한 줄이 대략 60바이트 — 300바이트면 5줄 안팎만 남는다
    final logger = build(maxBytes: 300);

    for (var i = 0; i < 50; i++) {
      await logger.log('bulk', '메시지 $i');
    }

    final content = await logger.readAll();
    expect(await logFile.length(), lessThanOrEqualTo(400));
    // 최근 것이 살아있어야 한다
    expect(content, contains('메시지 49'));
    expect(content, isNot(contains('메시지 0\n')));
  });

  test('줄바꿈이 든 메시지도 한 줄로 눕는다 — 회전이 깨지지 않는다', () async {
    final logger = build();

    await logger.log('multi', '첫째 줄\n둘째 줄\r셋째 줄');

    final lines = (await logger.readAll()).trim().split('\n');
    expect(lines, hasLength(1));
    expect(lines.single, contains('첫째 줄 둘째 줄 셋째 줄'));
  });

  test('clear 는 파일을 비운다', () async {
    final logger = build();
    await logger.log('a', '지워질 내용');

    await logger.clear();

    expect(await logger.readAll(), isEmpty);
  });

  test('파일이 없어도 readAll 이 터지지 않는다', () async {
    final logger = build();
    expect(await logger.readAll(), isEmpty);
  });

  test('쓸 수 없는 경로여도 예외를 올리지 않는다', () async {
    // 로깅 실패가 앱을 멈추면 본말전도다 — 특히 백그라운드에서는
    // 그대로 감시가 죽는다
    final logger = FileDiagnosticLogger(
      file: File('/proc/nonexistent/cannot/write.log'),
      maxBytes: 1024,
      clock: () => DateTime.utc(2026, 8, 14),
    );

    await logger.log('tag', '메시지');
    expect(await logger.readAll(), isEmpty);
    await logger.clear();
  });

  test('연속 기록이 섞이지 않는다', () async {
    final logger = build(maxBytes: 100000);

    // 판정 경로에서 여러 로그가 거의 동시에 발생한다
    await Future.wait([
      for (var i = 0; i < 20; i++) logger.log('concurrent', '동시 $i'),
    ]);

    final lines = (await logger.readAll())
        .trim()
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();

    expect(lines, hasLength(20));
    // 모든 줄이 온전한 형식이어야 한다 — 섞였으면 형식이 깨진다
    for (final line in lines) {
      expect(line, startsWith('2026-08-14T'));
      expect(line, contains('[concurrent]'));
    }
  });
}
