import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../data/place_routine_providers.dart';
import '../../domain/alert_place.dart';
import '../place_routine_controller.dart';

/// 홈 장소 시트 위 루틴 칩 줄 (#315): 칩 = 켜짐 표시 + 누르면 켜고 끄기, 끝 칩 = 관리
///
/// 루틴이 없으면 그리지 않음 (무료 사용자 홈은 그대로)
class PlaceRoutineChipBar extends ConsumerWidget {
  const PlaceRoutineChipBar({
    required this.places,
    required this.onManageRoutines,
    super.key,
  });

  final List<AlertPlace> places;
  final VoidCallback onManageRoutines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(placeRoutineListProvider).valueOrNull;
    if (routines == null || routines.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (final routine in routines) ...[
            FilterChip(
              avatar: const Icon(Icons.route_outlined),
              label: Text(routine.name),
              selected: routine.isOnFor(places),
              onSelected: routine.placesIn(places).isEmpty
                  ? null
                  : (_) => ref
                        .read(placeRoutineActionsProvider.notifier)
                        .toggle(routine, places),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          ActionChip(
            avatar: const Icon(Icons.tune_outlined),
            label: Text(context.l10n.routineManage),
            onPressed: onManageRoutines,
          ),
        ],
      ),
    );
  }
}
