import 'diagnostic_log_file.dart';

/// 합쳐 읽은 로그 한 줄: 출처, 정렬 시각, 원문 > 태그·내용 분해 (이슈 #290)
///
/// 원문 형식 `2026-08-14T01:23:45.678Z [tag] message`. 형식이 깨진 줄은
/// 태그 없이 원문 전체를 내용으로 둔다.
class DiagnosticLine {
  DiagnosticLine({required this.source, required this.at, required this.raw}) {
    final match = _format.firstMatch(raw);
    hasTimestamp = match != null;
    tag = match?.group(2) ?? '';
    message = match?.group(3) ?? raw;
  }

  final DiagnosticLogSource source;

  /// 줄 앞 시각. 시각이 없는 줄은 같은 파일 바로 앞 줄 시각 (정렬용)
  final DateTime at;

  final String raw;

  late final bool hasTimestamp;
  late final String tag;
  late final String message;

  static final _format = RegExp(r'^(\S+)\s+\[([^\]]+)\]\s+(.*)$');

  // 실패 신호 단어 (영어 고정 로그 토큰, CLAUDE.md 로그 규칙)
  static final _problemWords = RegExp(
    r'fail|error|exception|crash|timeout|timed out|rejected|dropped|'
    r'unavailable|unreadable|missing|interrupted|denied|not registered|lost',
    caseSensitive: false,
  );

  // 줄 전체가 문제 기록인 태그: exit 프로세스 종료 이력
  static const _problemTags = {'exit'};

  /// 실패·거부·종료 기록인가 (진단 화면 강조·"문제만" 필터 기준)
  bool get isProblem =>
      _problemTags.contains(tag) || _problemWords.hasMatch(message);

  /// 내보내기 한 줄: `app     2026-...Z [tag] message`
  String toReportLine() => '${source.reportLabel.padRight(7)}$raw';
}

/// 출처 파일 1개 요약: 크기·보관본 크기·줄 수·기간 (이슈 #290)
class DiagnosticSourceSummary {
  const DiagnosticSourceSummary({
    required this.source,
    required this.fileBytes,
    required this.archiveBytes,
    required this.lineCount,
    this.firstAt,
    this.lastAt,
    this.error = '',
  });

  final DiagnosticLogSource source;
  final int fileBytes;

  /// gzip 보관본 크기 (보관본 없는 출처는 0)
  final int archiveBytes;
  final int lineCount;
  final DateTime? firstAt;
  final DateTime? lastAt;

  /// 읽기 실패 사유. 비어 있으면 정상
  final String error;

  String toReportLine() =>
      'source=${source.reportLabel} file=${source.fileName} '
      'bytes=$fileBytes archive_bytes=$archiveBytes lines=$lineCount '
      'first=${firstAt?.toIso8601String() ?? '-'} '
      'last=${lastAt?.toIso8601String() ?? '-'}'
      '${error.isEmpty ? '' : ' error=$error'}';
}

/// 전체 출처를 시각순으로 합친 결과 (오래된 것 먼저)
class DiagnosticLogSnapshot {
  const DiagnosticLogSnapshot({
    required this.lines,
    required this.sources,
    required this.error,
  });

  final List<DiagnosticLine> lines;
  final List<DiagnosticSourceSummary> sources;

  /// 출처별 읽기 실패 사유 합본. 비어 있으면 전부 읽음
  final String error;
}
