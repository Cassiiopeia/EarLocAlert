import 'dart:io';
import 'dart:isolate';

import 'package:ear_loc_alert/core/diagnostics/diagnostic_log_file.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_log_reader.dart';
import 'package:ear_loc_alert/core/diagnostics/file_diagnostic_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 주체별 로그 파일과 시각순 합치기 (이슈 #231)
///
/// 앱 isolate 와 iOS 지오펜스 콜백 isolate 가 한 파일에 append 하자 줄이
/// 겹쳐 깨졌다(`ng=null` 로 시작하는 줄). Dart 의 append 는 "끝으로 이동 →
/// 쓰기"라 isolate 끼리 원자적이지 않다. 파일을 나누고 읽을 때 합친다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeByTimestamp', () {
    test('여러 파일의 줄을 시각순으로 합친다', () {
      final merged = DiagnosticLogReader.mergeByTimestamp([
        '2026-10-08T03:12:26.100000Z [app] a1\n'
            '2026-10-08T03:12:28.000000Z [app] a2\n',
        '2026-10-08T03:12:27.000000Z [geofence] b1\n',
        '2026-10-08T03:12:25.000Z [watch] n1\n',
      ]);

      expect(merged.trim().split('\n').map((l) => l.split(' ').last), [
        'n1',
        'a1',
        'b1',
        'a2',
      ]);
    });

    test('밀리초(네이티브)와 마이크로초(Dart) 표기를 시각으로 비교한다', () {
      // 문자열로 비교하면 '.123Z' 가 '.123456Z' 뒤로 간다 — 'Z' > '4'
      final merged = DiagnosticLogReader.mergeByTimestamp([
        '2026-10-08T03:12:26.123456Z [app] dart\n',
        '2026-10-08T03:12:26.123Z [watch] native\n',
      ]);

      expect(merged.indexOf('native'), lessThan(merged.indexOf('dart')));
    });

    test('시각이 없는 깨진 줄은 같은 파일의 앞 줄 자리에 남는다', () {
      final merged = DiagnosticLogReader.mergeByTimestamp([
        '2026-10-08T03:00:00.000Z [app] before\n'
            'ng=null broken tail\n'
            '2026-10-08T03:00:05.000Z [app] after\n',
        '2026-10-08T03:00:02.000Z [geofence] other\n',
      ]);

      final lines = merged.trim().split('\n');
      expect(lines, [
        '2026-10-08T03:00:00.000Z [app] before',
        'ng=null broken tail',
        '2026-10-08T03:00:02.000Z [geofence] other',
        '2026-10-08T03:00:05.000Z [app] after',
      ]);
    });

    test('같은 시각이면 파일 순서 → 줄 순서 — 열 때마다 순서가 같다', () {
      final merged = DiagnosticLogReader.mergeByTimestamp([
        '2026-10-08T03:00:00.000Z [app] x\n'
            '2026-10-08T03:00:00.000Z [app] y\n',
        '2026-10-08T03:00:00.000Z [bg] z\n',
      ]);

      expect(merged.trim().split('\n').map((l) => l.split(' ').last), [
        'x',
        'y',
        'z',
      ]);
    });

    test('모두 비어 있으면 빈 문자열', () {
      expect(DiagnosticLogReader.mergeByTimestamp(['', '\n']), isEmpty);
    });
  });

  group('주체별 파일', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('earloc_log_merge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('주체마다 파일명이 다르다 — 같으면 isolate 끼리 줄이 겹친다', () {
      final names = DiagnosticLogSource.values.map((s) => s.fileName).toSet();
      expect(names, hasLength(DiagnosticLogSource.values.length));
      // Kotlin DiagnosticLog.kt 와의 계약
      expect(DiagnosticLogSource.native.fileName, 'diagnostic.log');
    });

    test('두 isolate 가 동시에 써도 한 줄도 깨지거나 사라지지 않는다', () async {
      const perIsolate = 400;
      final appPath = '${tempDir.path}/${DiagnosticLogSource.app.fileName}';
      final bgPath =
          '${tempDir.path}/${DiagnosticLogSource.background.fileName}';

      await Future.wait([
        Isolate.run(() => _writeLines(appPath, 'app', perIsolate)),
        Isolate.run(() => _writeLines(bgPath, 'bg', perIsolate)),
      ]);

      final result = await DiagnosticLogReader.read();
      final lines = DiagnosticLogReader.linesOf(result.content);
      final wellFormed = RegExp(r'^\S+Z \[(app|bg)\] line-\d+ x+$');

      expect(result.error, isEmpty);
      expect(lines, hasLength(perIsolate * 2));
      expect(lines.where((l) => !wellFormed.hasMatch(l)), isEmpty);
    });

    test('지우기와 용량은 모든 주체 파일을 본다', () async {
      for (final source in DiagnosticLogSource.values) {
        await File(
          '${tempDir.path}/${source.fileName}',
        ).writeAsString('2026-10-08T03:00:00.000Z [x] ${source.name}\n');
      }

      expect(await DiagnosticLogReader.sizeInBytes(), greaterThan(0));
      final before = (await DiagnosticLogReader.read()).content;
      for (final source in DiagnosticLogSource.values) {
        expect(before, contains(source.name));
      }

      await DiagnosticLogReader.clear();

      expect((await DiagnosticLogReader.read()).content, isEmpty);
      expect(await DiagnosticLogReader.sizeInBytes(), 0);
    });
  });
}

/// 다른 isolate 에서 로거 하나로 [count] 줄을 쓴다
Future<void> _writeLines(String path, String tag, int count) async {
  final logger = FileDiagnosticLogger(file: File(path));
  await Future.wait([
    for (var i = 0; i < count; i++)
      logger.log(tag, 'line-$i ${'x' * (1 + i % 40)}'),
  ]);
}
