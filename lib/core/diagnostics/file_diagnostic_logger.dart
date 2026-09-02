import 'dart:async';
import 'dart:io';

import 'diagnostic_entry.dart';
import 'diagnostic_log_reader.dart';
import 'diagnostic_logger.dart';
import 'log_archive.dart';
import 'log_rotation.dart';

/// 파일 기반 진단 로거 (이슈 #95)
///
/// **왜 파일인가** — 이 앱은 세 곳에서 로그를 남긴다: 앱 isolate, 감시
/// 서비스가 보유한 백그라운드 엔진(별도 isolate), 그리고 Kotlin 계층.
/// Drift 는 Kotlin 에서 쓰기 어렵고, `logcat` 은 Android 4.1+ 부터 앱이
/// 자기 프로세스 로그조차 읽을 수 없어 쓸 수 없다. 파일 append 는 셋 다
/// 접근할 수 있는 유일한 공통분모다.
///
/// 앱 전용 디렉토리에 두므로 다른 앱이 읽지 못한다.
class FileDiagnosticLogger implements DiagnosticLogger {
  FileDiagnosticLogger({
    required this.file,
    this.archive,
    this.maxBytes = defaultMaxBytes,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// 2MB — 대략 만 줄이다. 문제가 생기고 며칠 뒤에 확인해도 추적된다.
  ///
  /// 5MB 에서 낮췄다 (이슈 #110). 기록을 알림 경로 전반으로 늘리면서
  /// 쌓이는 속도가 빨라졌고, 회전 한 번에 읽고 쓰는 양이 그만큼 커진다.
  static const int defaultMaxBytes = 2 * 1024 * 1024;

  /// 회전 후 남길 비율 (이슈 #110).
  ///
  /// **상한까지만 자르면 다음 한 줄에 또 넘는다.** 그러면 기록할 때마다
  /// 파일 전체를 읽고 자르고 다시 쓰게 되어, 로그 한 줄이 수 메가바이트
  /// I/O 가 된다 — 백그라운드 판정 경로에서 이건 그냥 고장이다.
  ///
  /// 70% 로 자르면 30% 만큼의 여유가 생겨 그동안은 회전이 일어나지 않는다.
  static const double _keepRatioAfterRotate = 0.7;

  final File file;

  /// 압축 보관본 (이슈 #127). null 이면 예전처럼 잘라내기만 한다 —
  /// 기존 테스트가 이 인자 없이 로거를 만들 수 있어야 한다.
  final File? archive;

  final int maxBytes;
  final DateTime Function() _clock;

  /// 쓰기를 직렬화한다.
  ///
  /// 판정 경로에서 여러 로그가 거의 동시에 발생하는데, append 를 동시에
  /// 걸면 줄이 섞여 읽을 수 없게 된다. 회전(읽고-자르고-다시쓰기)이
  /// 끼어들면 그 사이 기록이 통째로 날아가기도 한다.
  Future<void> _queue = Future.value();

  @override
  Future<void> log(String tag, String message) {
    final entry = DiagnosticEntry(
      timestampUtc: _clock().toUtc(),
      tag: tag,
      message: message,
    );
    return _serialize(() => _append(entry));
  }

  @override
  Future<String> readAll() {
    return _serialize(() async {
      try {
        // **보관본이 먼저다** (이슈 #127) — 시간순으로 읽혀야 한다
        final older = archive == null
            ? ''
            : await LogArchive.readArchive(archive!);
        if (!await file.exists()) return older;
        // **깨진 바이트가 있어도 읽어낸다** (이슈 #106).
        // 두 프로세스가 같은 파일에 쓰다 보면 한글 한 글자가 중간에서
        // 잘릴 수 있는데, `readAsString()` 은 그 순간 통째로 예외를 던진다.
        // 그것을 "로그 없음"으로 삼키면 수천 줄이 한 글자 때문에 사라진다
        final current = DiagnosticLogReader.decodeTolerant(
          await file.readAsBytes(),
        );
        return '$older$current';
      } on Object {
        // 읽기 실패는 "로그 없음"으로 본다
        return '';
      }
    });
  }

  @override
  Future<void> clear() {
    return _serialize(() async {
      try {
        if (await file.exists()) await file.writeAsString('');
        // 보관본도 함께 지운다 — 지웠는데 예전 기록이 남아 있으면
        // 사용자는 지우기가 고장 났다고 본다
        final older = archive;
        if (older != null && await older.exists()) await older.delete();
      } on Object {
        // 지우기 실패는 삼킨다
      }
    });
  }

  Future<void> _append(DiagnosticEntry entry) async {
    try {
      final parent = file.parent;
      if (!await parent.exists()) await parent.create(recursive: true);

      await file.writeAsString(
        '${entry.format()}\n',
        mode: FileMode.append,
        flush: true,
      );

      await _rotateIfNeeded();
    } on Object {
      // **로그를 못 남기는 것은 불편이지 고장이 아니다.** 로깅이 앱을
      // 멈추면 본말이 전도된다 — 백그라운드에서는 그대로 감시가 죽는다.
    }
  }

  /// 상한을 넘으면 오래된 쪽을 버린다.
  ///
  /// 매 기록마다 길이를 재는 것은 싸다(메타데이터 조회). 실제 재작성은
  /// 상한을 넘은 순간에만 일어나고, **그때 상한보다 넉넉히 잘라** 다음
  /// 회전까지 여유를 둔다 (이슈 #110).
  Future<void> _rotateIfNeeded() async {
    final length = await file.length();
    if (length <= maxBytes) return;

    // **버리지 않고 압축해 보관한다** (이슈 #127). 실기기에서 정밀 감시가
    // 도는 날은 하루 만에 상한이 차서, 예전 방식으로는 전날 기록을 볼 수
    // 없었다. 텍스트라 gzip 이 대략 10:1 로 줄인다.
    final target = archive;
    if (target != null) {
      final archived = await LogArchive.rotate(source: file, archive: target);
      if (archived) return;
      // 압축 실패는 아래 잘라내기로 떨어진다 — 여기서 포기하면 파일이
      // 상한을 넘은 채 영영 자란다
    }

    // 회전도 관대한 디코딩을 쓴다 — 여기서 예외가 나면 파일이 상한을
    // 넘은 채 영영 자라고, 결국 읽기가 더 무거워진다 (이슈 #106)
    final content = DiagnosticLogReader.decodeTolerant(
      await file.readAsBytes(),
    );
    final trimmed = trimToLimit(
      content,
      (maxBytes * _keepRatioAfterRotate).round(),
    );
    await file.writeAsString(trimmed, flush: true);
  }

  /// 앞선 작업이 끝난 뒤에 실행한다 — 실패해도 큐가 끊기지 않는다.
  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}
