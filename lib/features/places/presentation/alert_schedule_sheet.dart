import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/alert_schedule.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/text/keep_all.dart';
import 'alert_schedule_summary.dart';

/// 시간 창 하나를 만들거나 고치는 바텀시트 (이슈 #81)
///
/// 반환값이 `null` 이면 취소다.
Future<AlertSchedule?> showAlertScheduleSheet(
  BuildContext context, {
  AlertSchedule? initial,
}) {
  return showAppBottomSheet<AlertSchedule>(
    context,
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

  bool get _isValid => _days.isNotEmpty && _start != _end;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final l10n = context.l10n;

    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.schedule_outlined,
      title: isEdit ? l10n.scheduleSheetEditTitle : l10n.scheduleSheetAddTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.scheduleDaysLabel, style: context.appTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          // 빠른 선택 — 평일/주말/매일은 손이 가장 자주 가는 조합이다
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              _quickChip(l10n.scheduleWeekdays, const {1, 2, 3, 4, 5}),
              _quickChip(l10n.scheduleWeekends, const {6, 7}),
              _quickChip(l10n.scheduleEveryday, const {1, 2, 3, 4, 5, 6, 7}),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(weekdayShortName(l10n, day)),
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
              Expanded(
                child: _timeField(l10n.scheduleStart, _start, _pickStart),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _timeField(l10n.scheduleEnd, _end, _pickEnd)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_start > _end)
            Text(
              context.keepAllText(
                l10n.scheduleCrossesMidnight(describeSchedule(l10n, _current)),
              ),
              style: context.appTextStyles.caption,
            )
          else if (_start == _end)
            Text(
              context.keepAllText(l10n.scheduleSameStartEnd),
              style: context.appTextStyles.caption,
            ),
        ],
      ),
      primaryAction: FilledButton(
        onPressed: _isValid ? () => Navigator.of(context).pop(_current) : null,
        child: Text(isEdit ? l10n.scheduleSave : l10n.scheduleAddButton),
      ),
      secondaryAction: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.scheduleCancel),
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
          style: context.appTextStyles.body,
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await _pickTime(_start, context.l10n.scheduleStart);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await _pickTime(_end, context.l10n.scheduleEnd);
    if (picked != null) setState(() => _end = picked);
  }

  /// 휠로 시·분을 고른다. 시계 다이얼은 손가락으로 돌려 맞추기 불편해
  /// 오전/오후·시·분 세 칸을 위아래로 넘기는 방식을 쓴다.
  Future<int?> _pickTime(int minuteOfDay, String title) {
    return showAppBottomSheet<int>(
      context,
      builder: (_) => _TimeWheelSheet(initial: minuteOfDay, title: title),
    );
  }
}

/// 시·분 휠 시트. 확인을 눌러야 값이 반영되고, 취소하면 `null` 이다.
///
/// 시간 창 시트와 별개 위젯이다 — 한 위젯에 주 버튼이 둘이면 위계가 갈린다.
class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initial, required this.title});

  final int initial;

  /// 어느 시각을 고르는지 — 시작 / 종료
  final String title;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  // 휠을 돌리는 동안의 값
  late int _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.schedule_outlined,
      title: widget.title,
      body: SizedBox(
        height: 216,
        child: CupertinoTheme(
          // 휠 글자색은 밝기를 따라야 한다 — 다크로 박아 두면 라이트에서 흰 바탕에
          // 흰 글자가 된다 (#272 QA)
          data: CupertinoThemeData(brightness: Theme.of(context).brightness),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: false,
            // 날짜는 쓰지 않는다 — 시·분만 뽑아 쓴다
            initialDateTime: DateTime(
              2000,
              1,
              1,
              widget.initial ~/ 60,
              widget.initial % 60,
            ),
            onDateTimeChanged: (value) =>
                _selected = value.hour * 60 + value.minute,
          ),
        ),
      ),
      primaryAction: FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: Text(l10n.scheduleSave),
      ),
      secondaryAction: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.scheduleCancel),
      ),
    );
  }
}
