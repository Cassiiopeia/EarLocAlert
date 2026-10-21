import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../text/two_digits.dart';
import 'diagnostic_log_reader.dart';

/// 디버그 보고서: 앱 상태 + 로그 파일 요약 + 전체 로그(오래된 것 먼저) (이슈 #290)
///
/// 받는 사람이 앱 없이 이 파일 하나로 "그때 무슨 상태였고 무슨 일이 있었나"를
/// 추적하는 것이 목적이다. 머리말은 영어 고정 (로그와 같은 규칙).
abstract final class DebugReport {
  // 구역 구분선 (검색·눈으로 찾기 쉬운 고정 문자열)
  static const _rule = '========================================';

  /// 보고서 본문 조립 (앱 상태 > 로그 파일 요약 > 로그 전체)
  static Future<String> compose({
    required String appState,
    DateTime? now,
  }) async {
    final generatedAt = now ?? DateTime.now();
    final snapshot = await DiagnosticLogReader.readSnapshot();
    final buffer = StringBuffer()
      ..writeln('EarLocAlert debug report')
      ..writeln('generated_local=${_localStamp(generatedAt)}')
      ..writeln('generated_utc=${generatedAt.toUtc().toIso8601String()}')
      ..writeln()
      ..writeln('$_rule APP STATE')
      ..writeln(appState.isEmpty ? 'not collected' : appState.trimRight())
      ..writeln()
      ..writeln('$_rule LOG FILES');
    for (final source in snapshot.sources) {
      buffer.writeln(source.toReportLine());
    }
    if (snapshot.error.isNotEmpty) {
      buffer.writeln('read_error=${snapshot.error}');
    }
    buffer
      ..writeln()
      ..writeln(
        '$_rule LOGS (oldest first, lines=${snapshot.lines.length}, '
        'source column: app | bg | native | ios)',
      );
    for (final line in snapshot.lines) {
      buffer.writeln(line.toReportLine());
    }
    return buffer.toString();
  }

  /// 보고서를 캐시 디렉토리에 파일로 저장 (공유·메일 첨부용).
  ///
  /// 원본 로그를 그대로 공유하지 않는 이유 (이슈 #110):
  /// 1. `share_plus` FileProvider 범위가 `{캐시}/share_plus/` 뿐이라 `files/` 의
  ///    원본은 받는 앱이 열지 못한다
  /// 2. 공유 중에도 로그가 계속 쌓여 받는 앱이 읽을 때 이미 달라져 있다
  ///
  /// 확장자 `.txt`: `.log` 는 알려진 MIME 이 없어 받는 앱이 열기를 꺼린다.
  static Future<File> writeFile({
    required String appState,
    DateTime? now,
  }) async {
    final generatedAt = now ?? DateTime.now();
    final content = await compose(appState: appState, now: generatedAt);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/earlocalert-debug-${_fileStamp(generatedAt)}.txt',
    );
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// `2026-10-21 15:03:22 +09:00` — 받는 사람이 기기 시간대를 함께 본다
  static String _localStamp(DateTime at) {
    final local = at.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = twoDigits(offset.inHours.abs());
    final minutes = twoDigits(offset.inMinutes.abs() % 60);
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
        '${twoDigits(local.second)} $sign$hours:$minutes '
        '(${local.timeZoneName})';
  }

  /// `20261021-150322` — 여러 번 내보낸 파일이 섞이지 않게 초까지 (지역 시각)
  static String _fileStamp(DateTime at) {
    final local = at.toLocal();
    return '${local.year}${twoDigits(local.month)}${twoDigits(local.day)}'
        '-${twoDigits(local.hour)}${twoDigits(local.minute)}'
        '${twoDigits(local.second)}';
  }
}
