import '../../../core/diagnostics/diagnostic_line.dart';
import '../../../core/diagnostics/diagnostic_log_file.dart';

/// 진단 화면 필터: 검색어·출처·태그·문제만 (이슈 #290)
///
/// 조건 4개는 AND. 빈 검색어·null 출처·null 태그는 "전체".
class DiagnosticLineFilter {
  const DiagnosticLineFilter({
    this.query = '',
    this.source,
    this.tag,
    this.isProblemsOnly = false,
  });

  /// 원문 전체(시각·태그·내용) 대상, 대소문자 무시
  final String query;
  final DiagnosticLogSource? source;
  final String? tag;
  final bool isProblemsOnly;

  bool get isActive =>
      query.trim().isNotEmpty ||
      source != null ||
      tag != null ||
      isProblemsOnly;

  DiagnosticLineFilter copyWith({
    String? query,
    DiagnosticLogSource? Function()? source,
    String? Function()? tag,
    bool? isProblemsOnly,
  }) => DiagnosticLineFilter(
    query: query ?? this.query,
    source: source == null ? this.source : source(),
    tag: tag == null ? this.tag : tag(),
    isProblemsOnly: isProblemsOnly ?? this.isProblemsOnly,
  );

  bool matches(DiagnosticLine line) {
    if (source != null && line.source != source) return false;
    if (tag != null && line.tag != tag) return false;
    if (isProblemsOnly && !line.isProblem) return false;
    final needle = query.trim().toLowerCase();
    return needle.isEmpty || line.raw.toLowerCase().contains(needle);
  }

  /// 조건에 맞는 줄 > 최근 것이 위로 (방금 일어난 일을 찾으러 오는 화면)
  List<DiagnosticLine> apply(List<DiagnosticLine> oldestFirst) => [
    for (final line in oldestFirst.reversed)
      if (matches(line)) line,
  ];
}

/// 태그별 줄 수 > 많은 순 (필터 칩 순서)
List<MapEntry<String, int>> countLinesByTag(List<DiagnosticLine> lines) {
  final countByTag = <String, int>{};
  for (final line in lines) {
    if (line.tag.isEmpty) continue;
    countByTag[line.tag] = (countByTag[line.tag] ?? 0) + 1;
  }
  return countByTag.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
}
