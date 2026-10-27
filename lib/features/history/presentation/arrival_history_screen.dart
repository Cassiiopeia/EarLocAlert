import 'package:flutter/material.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/text/two_digits.dart';
import '../../../core/ui/components/grouped_list_row.dart';
import '../../../core/ui/components/grouped_list_section.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../../../core/ui/components/locked_content_blur.dart';
import '../../../core/ui/foundation/alert_direction_appearance.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_semantic_colors.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../domain/arrival_record.dart';

/// 도착 기록 화면 (#313): 요약 > 장소 거르기 > 날짜별 목록. 값과 등급은 app 계층이 내려줌
///
/// 무료: 최근 [freePreviewCount]건만 또렷하게, 요약·나머지는 흐린 잠금 > [onUnlockPro].
class ArrivalHistoryScreen extends StatefulWidget {
  const ArrivalHistoryScreen({
    required this.records,
    required this.isLocked,
    required this.onUnlockPro,
    required this.onRefresh,
    super.key,
  });

  /// null 이면 불러오는 중. 최신순
  final List<ArrivalRecord>? records;
  final bool isLocked;
  final VoidCallback onUnlockPro;
  final Future<void> Function() onRefresh;

  // 무료에서 또렷하게 보이는 최근 기록 수
  static const int freePreviewCount = 3;

  // 무료에서 흐리게 미리 보여 줄 기록 수 (화면이 길어지지 않게)
  static const int freeBlurredCount = 4;

  @override
  State<ArrivalHistoryScreen> createState() => _ArrivalHistoryScreenState();
}

class _ArrivalHistoryScreenState extends State<ArrivalHistoryScreen> {
  /// null 이면 전체 장소
  String? _selectedPlaceId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final records = widget.records;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: records == null
          ? const CenteredLoadingIndicator()
          : RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: records.isEmpty
                  ? _EmptyHistory(message: l10n.historyEmpty)
                  : _buildList(context, records),
            ),
    );
  }

  Widget _buildList(BuildContext context, List<ArrivalRecord> records) {
    final l10n = context.l10n;
    final filtered = _selectedPlaceId == null
        ? records
        : records.where((r) => r.placeId == _selectedPlaceId).toList();
    final isLocked = widget.isLocked;
    final visible = isLocked
        ? filtered.take(ArrivalHistoryScreen.freePreviewCount).toList()
        : filtered;
    final blurred = isLocked
        ? filtered
              .skip(ArrivalHistoryScreen.freePreviewCount)
              .take(ArrivalHistoryScreen.freeBlurredCount)
              .toList()
        : const <ArrivalRecord>[];

    final summary = _SummaryCard(
      summary: ArrivalSummary.from(records, DateTime.now().toUtc()),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      children: [
        if (isLocked)
          LockedContentBlur(
            caption: l10n.proLockedHistory,
            actionLabel: l10n.proUnlockAction,
            onUnlock: widget.onUnlockPro,
            child: summary,
          )
        else
          summary,
        const SizedBox(height: AppSpacing.sm),
        _PlaceFilterChips(
          records: records,
          selectedPlaceId: _selectedPlaceId,
          onSelected: (placeId) => setState(() => _selectedPlaceId = placeId),
        ),
        const SizedBox(height: AppSpacing.xs),
        ..._daySections(context, visible),
        if (blurred.isNotEmpty)
          LockedContentBlur(
            caption: l10n.proLockedHistory,
            actionLabel: l10n.proUnlockAction,
            onUnlock: widget.onUnlockPro,
            child: Column(children: _daySections(context, blurred)),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.keepAllText(l10n.historyRetentionNote),
          style: context.appTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Widget> _daySections(BuildContext context, List<ArrivalRecord> records) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final l10n = context.l10n;
    return [
      for (final day in groupArrivalsByLocalDay(records))
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GroupedListSection(
            header: _dayLabel(l10n, day.localDate),
            children: [
              for (final record in day.records)
                GroupedListRow.value(
                  icon: record.direction.outlinedIcon,
                  iconColor: record.direction.colorFrom(semantic),
                  title: record.placeName ?? l10n.historyDeletedPlace,
                  subtitle: record.direction == AlertDirection.exit
                      ? l10n.historyDeparted
                      : l10n.historyArrived,
                  valueText: _timeLabel(record.occurredAtUtc),
                  onTap: null,
                ),
            ],
          ),
        ),
    ];
  }

  static String _dayLabel(AppLocalizations l10n, DateTime localDate) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final difference = todayDate.difference(localDate).inDays;
    if (difference == 0) return l10n.historyToday;
    if (difference == 1) return l10n.historyYesterday;
    return l10n.historyDate(localDate.month, localDate.day);
  }

  static String _timeLabel(DateTime occurredAtUtc) {
    final local = occurredAtUtc.toLocal();
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

/// 요약 카드: 최근 30일 도착·출발 횟수, 가장 자주 울린 장소
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ArrivalSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPlaceName = summary.topPlaceName;
    return GroupedListSection(
      header: l10n.historySummaryTitle(ArrivalSummary.windowDays),
      children: [
        GroupedListRow.value(
          icon: AlertDirection.enter.outlinedIcon,
          title: l10n.historyArrivalCountTitle,
          valueText: l10n.historyCount(summary.arrivalCount),
          onTap: null,
        ),
        GroupedListRow.value(
          icon: AlertDirection.exit.outlinedIcon,
          title: l10n.historyDepartureCountTitle,
          valueText: l10n.historyCount(summary.departureCount),
          onTap: null,
        ),
        if (topPlaceName != null)
          GroupedListRow.value(
            icon: Icons.star_outline,
            title: l10n.historyTopPlaceTitle,
            subtitle: topPlaceName,
            valueText: l10n.historyCount(summary.topPlaceCount),
            onTap: null,
          ),
      ],
    );
  }
}

/// 장소 거르기 칩: 전체 + 기록에 나온 장소 (지운 장소 제외)
class _PlaceFilterChips extends StatelessWidget {
  const _PlaceFilterChips({
    required this.records,
    required this.selectedPlaceId,
    required this.onSelected,
  });

  final List<ArrivalRecord> records;
  final String? selectedPlaceId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final nameByPlaceId = <String, String>{};
    for (final record in records) {
      final name = record.placeName;
      if (name != null) nameByPlaceId.putIfAbsent(record.placeId, () => name);
    }
    if (nameByPlaceId.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.l10n.historyAllPlaces),
            selected: selectedPlaceId == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final entry in nameByPlaceId.entries) ...[
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              label: Text(entry.value),
              selected: selectedPlaceId == entry.key,
              onSelected: (selected) => onSelected(selected ? entry.key : null),
            ),
          ],
        ],
      ),
    );
  }
}

/// 기록 없음 (당겨서 새로고침이 되게 스크롤 가능)
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      Icon(
        Icons.history_outlined,
        size: AppIconSize.hero,
        color: context.appColors.textSecondary,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        context.keepAllText(message),
        style: context.appTextStyles.body,
        textAlign: TextAlign.center,
      ),
    ],
  );
}
