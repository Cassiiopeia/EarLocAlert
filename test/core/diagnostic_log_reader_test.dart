import 'dart:convert';
import 'dart:io';

import 'package:ear_loc_alert/core/diagnostics/diagnostic_log_file.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_log_reader.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:ear_loc_alert/core/diagnostics/file_diagnostic_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 진단 기록 읽기 (이슈 #106)
///
/// **이 테스트가 없어서 #106 이 실기기에서야 드러났다.**
/// 화면이 `Diagnostics.logger` 를 거쳐 읽던 구조라, 앱 시작 시 초기화가
/// 실패하면 파일에 기록이 잔뜩 있어도 "0건"으로 보였다. 로거 단위 테스트만
/// 있었고 **화면이 실제로 무엇을 읽는지는 아무도 확인하지 않았다.**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  late File logFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('earloc_log_reader');
    logFile = File('${tempDir.path}/${DiagnosticLogFile.fileName}');

    // `getApplicationSupportDirectory()` 를 임시 디렉토리로 돌린다
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);

    // 로거를 **초기화되지 않은 상태**로 둔다 — 그래도 읽혀야 한다는 것이
    // 이 테스트의 핵심이다
    Diagnostics.overrideLogger(const NoopDiagnosticLogger());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('로거가 초기화되지 않았어도 파일 내용을 읽는다 (이슈 #106)', () async {
    // 네이티브(Kotlin)가 남긴 기록은 Dart 초기화와 무관하게 파일에 있다.
    // 예전 구조에서는 이 상황이 통째로 "0건"이었다
    await logFile.writeAsString(
      '2026-08-19T10:00:00.000Z [watch] 감시 서비스 생성\n'
      '2026-08-19T10:00:01.000Z [registrar] 지오펜스 등록 성공 2개\n',
    );

    // 로거로 읽으면 빈 문자열이다 — 이것이 예전 화면이 보던 값이다
    expect(await Diagnostics.logger.readAll(), isEmpty);

    final result = await DiagnosticLogReader.read();

    expect(result.error, isEmpty);
    expect(result.content, contains('감시 서비스 생성'));
    expect(result.content, contains('지오펜스 등록 성공'));
  });

  test('파일이 없으면 빈 내용이고 오류는 없다', () async {
    final result = await DiagnosticLogReader.read();

    expect(result.content, isEmpty);
    // **"없음"과 "못 읽음"은 다르다** — 파일이 없는 것은 오류가 아니다
    expect(result.error, isEmpty);
  });

  test('최근 기록이 위로 온다', () {
    final lines = DiagnosticLogReader.linesOf(
      '2026-08-19T10:00:00.000Z [app] 먼저\n'
      '2026-08-19T10:00:05.000Z [app] 나중\n',
    );

    expect(lines.first, contains('나중'));
    expect(lines.last, contains('먼저'));
  });

  test('빈 줄은 세지 않는다 — 실제보다 많아 보이면 안 된다', () {
    final lines = DiagnosticLogReader.linesOf(
      '2026-08-19T10:00:00.000Z [app] 한 줄\n\n   \n\n',
    );

    expect(lines, hasLength(1));
  });

  test('지우면 내용이 비고, 파일이 없어도 실패하지 않는다', () async {
    await logFile.writeAsString('2026-08-19T10:00:00.000Z [app] 지울 것\n');

    await DiagnosticLogReader.clear();
    expect((await DiagnosticLogReader.read()).content, isEmpty);

    // 두 번째 호출은 파일이 비어 있는 상태 — 예외가 나면 안 된다
    await DiagnosticLogReader.clear();
  });

  test('깨진 바이트가 섞여 있어도 나머지를 읽어낸다 (이슈 #106)', () async {
    // 두 프로세스가 같은 파일에 append 하다 보면 한글 한 글자(3바이트)가
    // 중간에서 잘린다. 예전에는 `readAsString()` 이 통째로 예외를 던졌고,
    // 그것을 삼켜 **수천 줄이 한 글자 때문에 "기록 없음"이 됐다**
    final good = utf8.encode('2026-08-19T10:00:00.000Z [watch] 감시 서비스 생성\n');
    final broken = [0xED, 0x95]; // '한' 의 3바이트 중 둘만 — 불완전한 시퀀스
    final after = utf8.encode('\n2026-08-19T10:00:02.000Z [app] 그 뒤의 줄\n');
    await logFile.writeAsBytes([...good, ...broken, ...after]);

    final result = await DiagnosticLogReader.read();

    expect(result.error, isEmpty);
    expect(result.content, contains('감시 서비스 생성'));
    // **깨진 줄 뒤의 기록도 살아남아야 한다** — 그것이 대개 더 최근이다
    expect(result.content, contains('그 뒤의 줄'));
  });

  test('깨진 파일도 로거를 통해 읽힌다 — 빈 문자열로 둔갑하지 않는다', () async {
    final good = utf8.encode('2026-08-19T10:00:00.000Z [app] 살아있는 줄\n');
    await logFile.writeAsBytes([...good, 0xED, 0x95]);

    final logger = FileDiagnosticLogger(file: logFile);

    expect(await logger.readAll(), contains('살아있는 줄'));
  });

  test('경로를 못 잡으면 사유를 남긴다 — 조용히 "기록 없음"이 되지 않는다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'unavailable'),
        );

    final result = await DiagnosticLogReader.read();

    expect(result.content, isEmpty);
    expect(result.error, isNotEmpty);
  });
}
