import 'package:flutter/material.dart';

import '../../../core/domain/alert_schedule.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'alert_schedule_summary.dart';

/// 시간 창 하나를 만들거나 고치는 바텀시트 (이슈 #81)
///
/// 반환값이 `null` 이면 취소다.
Future<AlertSchedule?> showAlertScheduleSheet(
  BuildContext context, {
  AlertSchedule? initial,
}) {
  return showModalBottomSheet<AlertSchedule>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AlertScheduleSheet(initial: initial),
  );
}

class _AlertScheduleSheet extends StatefulWidget {
  const _AlertScheduleSheet({this.initial});

  final AlertSchedule? initial;

  @override
  State<_AlertScheduleSheet> createState() => _AlertScheduleSheetState();
}

class _AlertScheduleSheetState extends State<_AlertScheduleSheet> {
  // 기본값은 평일 08:00~10:00 — 가장 흔한 출근 시간대다. 처음 여는
  // 사용자가 아무것도 고르지 않고 바로 추가해도 말이 되는 값이어야 한다.
  late Set<int> _days = widget.initial == null
      ? {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        }
      : {...widget.initial!.daysOfWeek};

  late int _start = widget.initial?.startMinuteOfDay ?? 8 * 60;
  late int _end = widget.initial?.endMinuteOfDay ?? 10 * 60;

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  bool get _isValid => _days.isNotEmpty && _start != _end;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? '시간대 편집' : '시간대 추가',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),

          Text('요일', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          // 빠른 선택 — 평일/주말/매일은 손이 가장 자주 가는 조합이다
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              _quickChip('평일', const {1, 2, 3, 4, 5}),
              _quickChip('주말', const {6, 7}),
              _quickChip('매일', const {1, 2, 3, 4, 5, 6, 7}),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(_weekdayLabels[day - 1]),
                  selected: _days.contains(day),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _days.add(day);
                    } else {
                      _days.remove(day);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(child: _timeField('시작', _start, _pickStart)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _timeField('종료', _end, _pickEnd)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_start > _end)
            Text(
              '종료가 시작보다 이르므로 자정을 넘긴 것으로 봅니다 — '
              '${describeSchedule(_current)}',
              style: AppTypography.caption,
            )
          else if (_start == _end)
            Text(
              '시작과 종료가 같습니다. 하루 종일 알리려면 시간대를 만들지 '
              '않으면 됩니다.',
              style: AppTypography.caption,
            ),

          const SizedBox(height: AppSpacing.lg),
          // 주 버튼은 전체 폭 pill 이다 (docs/06-UX.md). 테마가 그것을
          // `minimumSize: Size.fromHeight(56)` 으로 강제하는데, 이 값은
          // **최소 너비가 무한대**라는 뜻이다. Column 은 자식에게 화면 폭을
          // 물려주므로 문제가 없지만, Row 는 폭을 제한하지 않아 버튼이
          // 무한히 넓어져 화면 밖으로 밀려난다 — 실제로 취소만 보이고
          // 추가 버튼이 사라졌다. 두 버튼을 세로로 쌓아 폭을 되돌린다.
          FilledButton(
            onPressed: _isValid
                ? () => Navigator.of(context).pop(_current)
                : null,
            child: Text(isEdit ? '저장' : '추가'),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ),
        ],
      ),
    );
  }

  AlertSchedule get _current => AlertSchedule(
    daysOfWeek: _days,
    startMinuteOfDay: _start,
    endMinuteOfDay: _end,
  );

  Widget _quickChip(String label, Set<int> days) {
    return ActionChip(
      label: Text(label),
      onPressed: () => setState(() => _days = {...days}),
    );
  }

  Widget _timeField(String label, int minuteOfDay, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          describeMinuteOfDay(minuteOfDay),
          style: AppTypography.body,
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await _pickTime(_start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await _pickTime(_end);
    if (picked != null) setState(() => _end = picked);
  }

  Future<int?> _pickTime(int minuteOfDay) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }
}
