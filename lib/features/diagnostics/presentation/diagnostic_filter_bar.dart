import 'package:flutter/material.dart';

import '../../../core/diagnostics/diagnostic_log_file.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../domain/diagnostic_line_filter.dart';

/// 진단 화면 필터 줄: 검색창 > 문제만·출처 칩 > 태그 칩 (이슈 #290)
///
/// 칩을 다시 누르면 해제. 출처·태그 칩은 실제로 기록이 있는 것만 보인다.
class DiagnosticFilterBar extends StatelessWidget {
  const DiagnosticFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.searchController,
    required this.problemCount,
    required this.sources,
    required this.tagCounts,
    required this.sourceLabelOf,
  });

  final DiagnosticLineFilter filter;
  final ValueChanged<DiagnosticLineFilter> onFilterChanged;
  final TextEditingController searchController;
  final int problemCount;

  /// 기록이 1줄 이상 있는 출처
  final List<DiagnosticLogSource> sources;

  /// 태그별 줄 수 (많은 순)
  final List<MapEntry<String, int>> tagCounts;
  final String Function(DiagnosticLogSource) sourceLabelOf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: (query) =>
                onFilterChanged(filter.copyWith(query: query)),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.diagnosticsSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onFilterChanged(filter.copyWith(query: ''));
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChipRow(
            children: [
              FilterChip(
                label: Text(l10n.diagnosticsProblemsOnly(problemCount)),
                selected: filter.isProblemsOnly,
                onSelected: (selected) =>
                    onFilterChanged(filter.copyWith(isProblemsOnly: selected)),
              ),
              ChoiceChip(
                label: Text(l10n.diagnosticsAllSources),
                selected: filter.source == null,
                onSelected: (_) =>
                    onFilterChanged(filter.copyWith(source: () => null)),
              ),
              for (final source in sources)
                ChoiceChip(
                  label: Text(sourceLabelOf(source)),
                  selected: filter.source == source,
                  onSelected: (selected) => onFilterChanged(
                    filter.copyWith(source: () => selected ? source : null),
                  ),
                ),
            ],
          ),
          if (tagCounts.isNotEmpty)
            _ChipRow(
              children: [
                for (final MapEntry(key: tag, value: count) in tagCounts)
                  FilterChip(
                    label: Text('$tag $count'),
                    selected: filter.tag == tag,
                    onSelected: (selected) => onFilterChanged(
                      filter.copyWith(tag: () => selected ? tag : null),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 가로로 넘기는 칩 한 줄
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: child,
            ),
        ],
      ),
    );
  }
}
