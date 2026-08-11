import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/alert_place.dart';
import 'alert_schedule_summary.dart';
import 'place_list_controller.dart';

/// 장소 한 건 (docs/06-UX.md)
///
/// 활성 상태를 **배경 반전**으로 표현한다 — 어두운 목록 안의 밝은 카드.
/// 참조 미감(다크 핀테크)의 선택 표현을 그대로 따른다.
///
/// 지도 홈의 시트와 목록 양쪽에서 쓴다.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    required this.place,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.selected = false,
    super.key,
  });

  final AlertPlace place;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  /// 지도에서 마커를 눌러 지목된 상태.
  ///
  /// 활성/비활성(배경 반전)과 **다른 축이라 테두리로 표현한다.** 배경까지
  /// 바꾸면 "켜져 있음"과 "지금 보고 있음"을 구분할 수 없다.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final enabled = place.enabled;

    final background = enabled ? AppColors.bgInverse : AppColors.bgSurface;
    final foreground = enabled
        ? AppColors.textOnInverse
        : AppColors.textPrimary;
    final secondary = enabled
        ? AppColors.textOnInverse
        : AppColors.textSecondary;

    final (directionIcon, directionLabel, directionColor) = describeDirection(
      place.direction,
      semantic,
    );

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: selected
                ? Border.all(color: directionColor, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Icon(directionIcon, color: directionColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: AppTypography.body.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$directionLabel · 반경 ${place.radiusMeters}m',
                      style: AppTypography.caption.copyWith(color: secondary),
                    ),
                    // 시간대가 걸려 있으면 드러낸다 — 창 밖이라 안 울린
                    // 것을 알 방법이 없으면 사용자는 앱을 믿지 못한다
                    // (F4.5 와 같은 이유, 이슈 #81)
                    if (place.schedules.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        describeSchedules(place.schedules),
                        style: AppTypography.caption.copyWith(color: secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 활성 토글은 삭제와 분리한다 (F1.7)
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}

/// 알림 방향의 아이콘·문구·색.
///
/// 카드와 지도 마커가 같은 규칙을 쓰도록 한 곳에 둔다 — 색만으로 구분하지
/// 않고 아이콘·텍스트를 병행한다 (색각 이상 대응, docs/06-UX.md).
(IconData, String, Color) describeDirection(
  AlertDirection direction,
  AppSemanticColors semantic,
) => switch (direction) {
  AlertDirection.enter => (Icons.login_outlined, '도착 알림', semantic.alertEnter),
  AlertDirection.exit => (Icons.logout_outlined, '출발 알림', semantic.alertExit),
  AlertDirection.both => (
    Icons.sync_alt_outlined,
    '도착·출발',
    semantic.alertEnter,
  ),
};

/// 삭제는 실수를 되돌릴 수 있어야 한다.
///
/// 목록과 지도 시트가 같은 동작을 하도록 함수로 뺐다.
Future<void> deletePlaceWithUndo(
  BuildContext context,
  WidgetRef ref,
  AlertPlace place,
) async {
  final actions = ref.read(placeActionsProvider.notifier);
  final deleted = await actions.delete(place.id);
  if (deleted == null || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('\'${deleted.name}\' 삭제됨'),
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: () => actions.restore(deleted),
      ),
    ),
  );
}
