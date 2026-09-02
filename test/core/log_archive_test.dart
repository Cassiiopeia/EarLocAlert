import 'dart:io';

import 'package:ear_loc_alert/core/diagnostics/file_diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/log_archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// 로그 압축 보관 (이슈 #127)
///
/// **예전에는 상한을 넘으면 오래된 기록을 그냥 지웠다.** 실기기에서
/// 정밀 감시가 도는 날은 하루 만에 상한이 차서 전날 기록을 볼 수 없었다.
///
/// 진짜 파일 I/O 를 쓴다 — 압축·회전이 목적이라 가짜로는 의미가 없다.
void main() {
  late Directory tempDir;
  late File logFile;
  late File archiveFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('log_archive_test');
    logFile = File('${tempDir.path}/diagnostic.log');
    archiveFile = File('${tempDir.path}/diagnostic.1.log.gz');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('rotate', () {
    test('압축해 보관하고 원본을 비운다', () async {
      await logFile.writeAsString('첫 줄\n둘째 줄\n');

      final ok = await LogArchive.rotate(source: logFile, archive: archiveFile);

      expect(ok, isTrue);
      expect(await logFile.readAsString(), isEmpty);
      expect(await archiveFile.exists(), isTrue);
      expect(await LogArchive.readArchive(archiveFile), '첫 줄\n둘째 줄\n');
    });

    test('한국어가 왕복한다', () async {
      const content = '알림 발생 place=소만사 출근 direction=enter\n';
      await logFile.writeAsString(content);

      await LogArchive.rotate(source: logFile, archive: archiveFile);

      expect(await LogArchive.readArchive(archiveFile), content);
    });

    test('반복되는 로그는 크게 줄어든다', () async {
      // 실제 로그와 비슷한 모양 — 같은 형식이 반복된다
      final buffer = StringBuffer();
      for (var i = 0; i < 2000; i++) {
        buffer.writeln(
          '2026-09-01T23:0$i [engine] 정밀 판정 lat=37.4126384 '
          'lng=127.0971434 acc=24m → 알림없음 (검토 4곳)',
        );
      }
      await logFile.writeAsString(buffer.toString());
      final before = await logFile.length();

      await LogArchive.rotate(source: logFile, archive: archiveFile);
      final after = await archiveFile.length();

      expect(
        after,
        lessThan(before ~/ 5),
        reason:
            '텍스트 로그는 반복이 많아 크게 압축된다 — '
            '이것이 보관 기간을 늘리는 근거다',
      );
    });

    test('빈 파일은 보관하지 않는다', () async {
      await logFile.writeAsString('');

      final ok = await LogArchive.rotate(source: logFile, archive: archiveFile);

      expect(ok, isTrue);
      expect(await archiveFile.exists(), isFalse);
    });

    test('원본이 없으면 실패로 본다', () async {
      final ok = await LogArchive.rotate(
        source: File('${tempDir.path}/없는파일.log'),
        archive: archiveFile,
      );

      expect(ok, isFalse, reason: '호출자가 잘라내기로 떨어져야 파일이 무한정 자라지 않는다');
    });
  });

  group('readArchive', () {
    test('보관본이 없으면 빈 문자열', () async {
      expect(await LogArchive.readArchive(archiveFile), isEmpty);
    });

    test('깨진 보관본이 현재 로그를 막지 않는다', () async {
      await archiveFile.writeAsBytes([0, 1, 2, 3, 4]);

      expect(
        await LogArchive.readArchive(archiveFile),
        isEmpty,
        reason: '진단 화면은 무슨 일이 있어도 지금 기록을 보여줘야 한다',
      );
    });
  });

  group('로거와 함께', () {
    test('상한을 넘으면 보관본이 생기고 현재는 비워진다', () async {
      final logger = FileDiagnosticLogger(
        file: logFile,
        archive: archiveFile,
        maxBytes: 400,
        clock: () => DateTime.utc(2026, 9, 2, 12),
      );

      for (var i = 0; i < 20; i++) {
        await logger.log('test', '충분히 긴 메시지를 반복해서 상한을 넘긴다 $i');
      }

      expect(await archiveFile.exists(), isTrue);
      expect(
        await logFile.length(),
        lessThan(400),
        reason: '회전 후 현재 파일은 다시 작아야 한다',
      );
    });

    test('읽으면 보관본과 현재가 시간순으로 이어진다', () async {
      final logger = FileDiagnosticLogger(
        file: logFile,
        archive: archiveFile,
        maxBytes: 300,
        clock: () => DateTime.utc(2026, 9, 2, 12),
      );

      await logger.log('test', '아주 오래된 기록입니다 이 줄은 보관본으로 넘어갑니다');
      for (var i = 0; i < 6; i++) {
        await logger.log('test', '뒤이어 쌓이는 기록 $i 상한을 넘기기 위한 길이');
      }

      final all = await logger.readAll();

      expect(all, contains('아주 오래된 기록'), reason: '회전으로 넘어간 기록도 화면에서 보여야 한다');
      expect(all, contains('뒤이어 쌓이는 기록 5'));
      expect(
        all.indexOf('아주 오래된 기록'),
        lessThan(all.indexOf('뒤이어 쌓이는 기록 5')),
        reason: '오래된 쪽이 앞이어야 시간순으로 읽힌다',
      );
    });

    test('지우면 보관본도 사라진다', () async {
      final logger = FileDiagnosticLogger(
        file: logFile,
        archive: archiveFile,
        maxBytes: 300,
        clock: () => DateTime.utc(2026, 9, 2, 12),
      );
      for (var i = 0; i < 8; i++) {
        await logger.log('test', '상한을 넘기기 위한 충분히 긴 줄 $i');
      }
      expect(await archiveFile.exists(), isTrue);

      await logger.clear();

      expect(
        await archiveFile.exists(),
        isFalse,
        reason: '지웠는데 예전 기록이 남으면 지우기가 고장 난 것으로 보인다',
      );
      expect(await logger.readAll(), isEmpty);
    });

    test('보관본 없이도 예전처럼 동작한다', () async {
      final logger = FileDiagnosticLogger(
        file: logFile,
        maxBytes: 300,
        clock: () => DateTime.utc(2026, 9, 2, 12),
      );

      for (var i = 0; i < 10; i++) {
        await logger.log('test', '상한을 넘기기 위한 충분히 긴 줄 $i');
      }

      expect(await archiveFile.exists(), isFalse);
      expect(await logFile.length(), lessThanOrEqualTo(300));
    });
  });
}
