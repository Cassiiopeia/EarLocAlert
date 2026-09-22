import 'dart:async';

import 'package:flutter/foundation.dart';

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

  /// 초기화 전에 남긴 줄을 잠깐 담아둔다 (이슈 #150).
  ///
  /// 예전에는 조용히 버렸다. 그런데 **앱이 뜨는 순간의 판단**은 대개
  /// `init()` 보다 먼저 난다 — 스플래시 전환을 생략한 사유가 그랬고,
  /// 그 사유가 곧 "알림이 늦지 않았는가"의 답이었다. 버리면 그 순간을
  /// 영영 못 본다.
  ///
  /// 파일을 만지지 않고 메모리에만 쌓으므로 부팅을 막지 않는다. 상한을
  /// 두는 것은 `init()` 이 영영 안 오는 경로(초기화 실패)에서 무한히
  /// 자라지 않게 하기 위해서다 — 넘치면 오래된 것부터 버린다.
  static const _preInitLimit = 32;
  static final List<(String, String)> _preInit = [];

  /// 실제 파일 로거로 교체한다. 앱·백그라운드 엔진 양쪽에서 부른다.
  ///
  /// 초기화 전에 쌓인 줄을 먼저 흘려보낸 뒤 이어서 기록한다.
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
    _flushPreInit();
  }

  /// 쌓인 줄을 **순서대로** 흘려보낸다. 시간순이 깨지면 읽을 수 없다.
  ///
  /// 실제 로거가 꽂히는 자리마다 부른다 — `init()` 이든 테스트의
  /// `overrideLogger()` 든, 한쪽만 부르면 그 경로에서 기록이 사라진다.
  static void _flushPreInit() {
    if (_preInit.isEmpty) return;
    final buffered = List.of(_preInit);
    _preInit.clear();
    for (final (tag, message) in buffered) {
      log(tag, message);
    }
  }

  /// 테스트에서 갈아끼운다.
  static void overrideLogger(DiagnosticLogger logger) {
    _logger = logger;
    _initialized = true;
    _flushPreInit();
  }

  static DiagnosticLogger get logger => _logger;

  /// 한 줄 남긴다. **await 하지 않아도 된다** — 판정 경로에서 로깅을
  /// 기다리면 알림이 늦어진다.
  static void log(String tag, String message) {
    if (!_initialized) {
      if (_preInit.length >= _preInitLimit) _preInit.removeAt(0);
      _preInit.add((tag, message));
      return;
    }
    unawaited(_logger.log(tag, message).catchError((_) {}));
  }

  /// 테스트에서 선버퍼를 비운다 — 케이스 사이에 새지 않게.
  @visibleForTesting
  static void resetForTest() {
    _preInit.clear();
    _initialized = false;
    _logger = const NoopDiagnosticLogger();
  }
}
