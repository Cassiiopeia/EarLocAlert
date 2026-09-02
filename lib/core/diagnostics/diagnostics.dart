import 'dart:async';

import 'diagnostic_log_file.dart';
import 'diagnostic_logger.dart';
import 'file_diagnostic_logger.dart';

/// 진단 로그의 전역 진입점 (이슈 #95)
///
/// **왜 Riverpod 이 아니라 전역인가** — 로그를 남겨야 하는 곳 중 상당수가
/// Provider 컨테이너 밖이다. 백그라운드 isolate 의 지오펜스 콜백, 감시
/// 서비스 엔진의 진입점, `data` 계층의 채널 어댑터에는 `Ref` 가 없다.
/// 그 지점들이 정확히 **가장 로그가 필요한 곳**이라, 컨테이너를 요구하면
/// 로깅이 닿지 못한다.
///
/// 상태 관리 규칙(docs/04-CONVENTIONS.md — Riverpod 단독)의 예외다.
/// 이것은 화면 상태가 아니라 **부수효과 기록 채널**이라 화면 재구성·
/// 테스트 격리와 무관하다.
///
/// **어떤 호출도 예외를 올리지 않는다.** 로그를 못 남기는 것은 불편이지
/// 고장이 아니다.
abstract final class Diagnostics {
  static DiagnosticLogger _logger = const NoopDiagnosticLogger();
  static bool _initialized = false;

  /// 실제 파일 로거로 교체한다. 앱·백그라운드 엔진 양쪽에서 부른다.
  ///
  /// 초기화 전에 남긴 로그는 조용히 버려진다 — 부팅 순서에 로깅이
  /// 끼어들어 앱 시작을 막는 것보다 낫다.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _logger = FileDiagnosticLogger(
        file: await DiagnosticLogFile.resolve(),
        // 회전할 때 버리지 않고 압축해 보관한다 (이슈 #127)
        archive: await DiagnosticLogFile.resolveArchive(),
      );
    } on Object {
      // 파일을 못 잡으면 Noop 인 채로 둔다
    }
  }

  /// 테스트에서 갈아끼운다.
  static void overrideLogger(DiagnosticLogger logger) {
    _logger = logger;
    _initialized = true;
  }

  static DiagnosticLogger get logger => _logger;

  /// 한 줄 남긴다. **await 하지 않아도 된다** — 판정 경로에서 로깅을
  /// 기다리면 알림이 늦어진다.
  static void log(String tag, String message) {
    unawaited(_logger.log(tag, message).catchError((_) {}));
  }
}
