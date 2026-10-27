import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/text/keep_all.dart';
import '../../../../core/ui/components/grouped_list_row.dart';
import '../../../../core/ui/components/grouped_list_section.dart';
import '../../../../core/ui/components/loading_indicator.dart';
import '../../../../core/ui/components/locked_content_blur.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../data/place_routine_providers.dart';
import '../../domain/alert_place.dart';
import '../../domain/place_routine.dart';
import '../place_list_controller.dart';
import '../place_routine_controller.dart';

/// 루틴 목록 화면 (#315): 루틴마다 켜기 스위치, 누르면 편집, 맨 아래 추가
///
/// 등급과 화면 이동은 app 계층이 내려줌. 잠겨도(환불) 이미 만든 루틴은 켜고 끌 수 있음
class PlaceRoutineListScreen extends ConsumerWidget {
  const PlaceRoutineListScreen({
    required this.isLocked,
    required this.onUnlockPro,
    required this.onAddRoutine,
    required this.onEditRoutine,
    super.key,
  });

  /// 무료라 새 루틴을 만들 수 없는가
  final bool isLocked;
  final VoidCallback onUnlockPro;
  final VoidCallback onAddRoutine;
  final ValueChanged<PlaceRoutine> onEditRoutine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routines = ref.watch(placeRoutineListProvider).valueOrNull;
    final places =
        ref.watch(placeListProvider).valueOrNull ?? const <AlertPlace>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routineTitle)),
      body: routines == null
          ? const CenteredLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              children: [
                Text(
                  context.keepAllText(l10n.routineDescription),
                  style: context.appTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (routines.isNotEmpty)
                  GroupedListSection(
                    children: [
                      for (final routine in routines)
                        _RoutineRow(
                          routine: routine,
                          places: places,
                          onEdit: () => onEditRoutine(routine),
                          onToggle: () => ref
                              .read(placeRoutineActionsProvider.notifier)
                              .toggle(routine, places),
                        ),
                    ],
                  )
                else if (isLocked)
                  LockedContentBlur(
                    caption: l10n.proLockedRoutines,
                    actionLabel: l10n.proUnlockAction,
                    onUnlock: onUnlockPro,
                    child: const _ExampleRoutines(),
                  ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: isLocked ? onUnlockPro : onAddRoutine,
                  icon: const Icon(Icons.add_outlined),
                  label: Text(l10n.routineAdd),
                ),
              ],
            ),
    );
  }
}

/// 루틴 한 줄: 이름, 장소 수·나머지 끄기, 켜기 스위치. 줄을 누르면 편집
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.places,
    required this.onEdit,
    required this.onToggle,
  });

  final PlaceRoutine routine;
  final List<AlertPlace> places;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final memberCount = routine.placesIn(places).length;
    final summary = memberCount == 0
        ? l10n.routineNoPlaces
        : l10n.routinePlaceCount(memberCount);
    return GroupedListRow.withTrailing(
      icon: Icons.route_outlined,
      title: routine.name,
      subtitle: routine.isExclusive
          ? '$summary · ${l10n.routineExclusiveShort}'
          : summary,
      onTap: onEdit,
      trailing: Switch(
        value: routine.isOnFor(places),
        onChanged: memberCount == 0 ? null : (_) => onToggle(),
      ),
    );
  }
}

/// 무료 잠금 뒤 흐린 예시 (실제 데이터 아님)
class _ExampleRoutines extends StatelessWidget {
  const _ExampleRoutines();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GroupedListSection(
      children: [
        for (final name in [
          l10n.routineExampleCommute,
          l10n.routineExampleHome,
        ])
          GroupedListRow.withTrailing(
            icon: Icons.route_outlined,
            title: name,
            subtitle: l10n.routinePlaceCount(3),
            trailing: const Switch(value: true, onChanged: null),
          ),
      ],
    );
  }
}
