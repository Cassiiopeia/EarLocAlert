import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 초기화 전에 남긴 로그 (이슈 #150)
///
/// **앱이 뜨는 순간의 판단은 대개 `init()` 보다 먼저 난다.** 스플래시
/// 전환을 생략한 사유가 그랬고, 그 사유가 곧 "알림이 늦지 않았는가"의
/// 답이었다. 예전처럼 버리면 그 순간을 영영 못 본다.
class _RecordingLogger implements DiagnosticLogger {
  final lines = <String>[];

  @override
  Future<void> log(String tag, String message) async {
    lines.add('[$tag] $message');
  }

  @override
  Future<String> readAll() async => lines.join('\n');

  @override
  Future<void> clear() async => lines.clear();
}

void main() {
  tearDown(Diagnostics.resetForTest);

  test('초기화 전에 남긴 줄이 초기화 뒤에 흘러나온다', () async {
    Diagnostics.resetForTest();
    Diagnostics.log('splash', '전환 애니메이션 생략 사유=핀 디코드 전');

    final logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
    await Future<void>.delayed(Duration.zero);

    expect(logger.lines, contains('[splash] 전환 애니메이션 생략 사유=핀 디코드 전'));
  });

  test('쌓인 순서를 지킨다 — 시간순이 깨지면 읽을 수 없다', () async {
    Diagnostics.resetForTest();
    Diagnostics.log('a', '첫째');
    Diagnostics.log('a', '둘째');
    Diagnostics.log('a', '셋째');

    final logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
    await Future<void>.delayed(Duration.zero);

    expect(logger.lines, ['[a] 첫째', '[a] 둘째', '[a] 셋째']);
  });

  test('상한을 넘으면 오래된 것부터 버린다', () async {
    Diagnostics.resetForTest();
    // init 이 영영 안 오는 경로에서 무한히 자라면 안 된다
    for (var i = 0; i < 40; i++) {
      Diagnostics.log('a', '$i');
    }

    final logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
    await Future<void>.delayed(Duration.zero);

    expect(logger.lines.length, 32);
    expect(logger.lines.first, '[a] 8', reason: '오래된 8건이 밀려난다');
    expect(logger.lines.last, '[a] 39');
  });
}
