import 'package:flutter/material.dart';

import '../../../core/domain/alert_schedule.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import 'alert_schedule_sheet.dart';
import 'alert_schedule_summary.dart';
import 'place_section_label.dart';

/// 장소의 알림 시간대 목록 편집 (이슈 #81)
///
/// 폼 화면에 끼워 넣는 섹션이다. 폼이 이미 260줄이라 여기로 분리했고,
/// 덕분에 다른 진입점에서도 그대로 쓸 수 있다.
///
/// **창이 하나도 없으면 항상 알림**이다 — 이 규약을 빈 상태 문구로
/// 드러낸다. 안 그러면 사용자는 "시간대를 안 정하면 안 울리나?"를 궁금해한다.
class AlertScheduleEditor extends StatelessWidget {
  const AlertScheduleEditor({
    required this.schedules,
    required this.onChanged,
    super.key,
  });

  final List<AlertSchedule> schedules;
  final ValueChanged<List<AlertSchedule>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 폼의 다른 칸과 같은 제목 줄 (이슈 #228)
        PlaceSectionLabel(context.l10n.scheduleTitle),

        if (schedules.isEmpty)
          Text(
            context.keepAllText(context.l10n.scheduleAlwaysHint),
            style: AppTypography.caption,
          )
        else
          for (final (index, schedule) in schedules.indexed)
            _ScheduleTile(
              schedule: schedule,
              onEdit: () => _edit(context, index),
              onRemove: () => _remove(index),
            ),

        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.more_time_outlined),
          label: Text(context.l10n.scheduleAdd),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final created = await showAlertScheduleSheet(context);
    if (created == null) return;
    onChanged([...schedules, created]);
  }

  Future<void> _edit(BuildContext context, int index) async {
    final edited = await showAlertScheduleSheet(
      context,
      initial: schedules[index],
    );
    if (edited == null) return;
    final next = [...schedules];
    next[index] = edited;
    onChanged(next);
  }

  void _remove(int index) {
    final next = [...schedules]..removeAt(index);
    onChanged(next);
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onEdit,
    required this.onRemove,
  });

  final AlertSchedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.schedule_outlined),
      title: Text(
        describeSchedule(context.l10n, schedule),
        style: AppTypography.body,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close_outlined),
        tooltip: context.l10n.scheduleRemove,
        onPressed: onRemove,
      ),
      onTap: onEdit,
    );
  }
}
