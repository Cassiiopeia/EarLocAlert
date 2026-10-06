import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/alert_place.dart';
import 'alert_schedule_summary.dart';
import 'place_list_controller.dart';

/// 장소 한 건 (docs/06-UX.md)
///
/// 활성 상태를 **명도와 채도**로 표현한다 — 활성은 밝은 층(bgElevated)에
/// 유색 아이콘, 비활성은 낮은 층에서 회색으로 가라앉는다 (이슈 #88).
///
/// 흰색 반전을 쓰지 않는 이유: 이 앱에서 활성은 예외가 아니라 **기본
/// 상태**다. 등록한 장소는 대부분 켜져 있는데, 예외 표현(반전)을 기본
/// 상태에 쓰면 다크 화면 하단이 통째로 하얗게 뜬다. 상태는 토글이 이미
/// 말해주므로 배경 반전 없이도 구분된다.
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
  /// 활성/비활성(배경 명도)과 **다른 축이라 테두리로 표현한다.** 배경까지
  /// 바꾸면 "켜져 있음"과 "지금 보고 있음"을 구분할 수 없다.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final enabled = place.enabled;

    final background = enabled ? AppColors.bgElevated : AppColors.bgSurface;
    final foreground = enabled
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    final secondary = AppColors.textSecondary;

    final (directionIcon, directionLabel, directionColor) = describeDirection(
      place.direction,
      semantic,
      context.l10n,
    );

    // 토글 전환을 부드럽게 — 기존에 정의된 모션(지도 홈 시트의
    // 200ms easeOut)을 그대로 쓴다. 잉크 리플이 색 위에 그려지도록
    // Material 은 투명으로 두고 색은 AnimatedContainer 가 든다.
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: selected ? Border.all(color: directionColor, width: 2) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                // 꺼진 장소는 아이콘도 가라앉는다 — 색만 남으면
                // "울리는 장소"로 오독된다
                Icon(
                  directionIcon,
                  color: enabled ? directionColor : AppColors.textSecondary,
                ),
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
                        context.l10n.placeRadiusInfo(
                          directionLabel,
                          place.radiusMeters,
                        ),
                        style: AppTypography.caption.copyWith(color: secondary),
                      ),
                      // 시간대가 걸려 있으면 드러낸다 — 창 밖이라 안 울린
                      // 것을 알 방법이 없으면 사용자는 앱을 믿지 못한다
                      // (F4.5 와 같은 이유, 이슈 #81)
                      if (place.schedules.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          describeSchedules(context.l10n, place.schedules),
                          style: AppTypography.caption.copyWith(
                            color: secondary,
                          ),
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
      ),
    );

    return _SwipeToDelete(
      semanticLabel: context.l10n.placeSwipeDeleteLabel,
      onDelete: onDelete,
      child: card,
    );
  }
}

/// 카드를 왼쪽으로 밀어 삭제한다 (이슈 #205).
///
/// 예전에는 길게 눌러야만 지워졌다. 눈에 보이는 단서가 없어 모르면 찾을 수
/// 없었고, 움직임도 없어 투박했다. 밀면 뒤에서 삭제가 드러나는 방식은
/// 목록 앱에서 이미 익숙한 문법이다.
///
/// **확인 창을 띄우지 않는다.** 삭제 직후 "되돌리기"가 있어 실수는 복구된다.
/// 지울 때마다 한 번 더 묻는 것은 부드러움을 해친다.
///
/// 되돌릴 수 없는 삭제(알림음·진단 기록)는 확인 창을 그대로 유지한다.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    required this.child,
    required this.onDelete,
    required this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onDelete;
  final String semanticLabel;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> {
  /// 미는 정도 0~1. 배경 농도와 아이콘 크기가 이것을 따라간다.
  final _progress = ValueNotifier<double>(0);

  /// 놓은 직후 true. [Dismissible] 은 `onDismissed` 뒤에 **같은 프레임
  /// 안에 트리에서 빠져야** 한다 — 저장소에서 지워진 목록이 다시 흘러오기
  /// 전에 다음 프레임이 그려지면 "dismissed widget is still part of the
  /// tree" 로 죽는다. 그래서 목록 갱신을 기다리지 않고 스스로 접는다.
  bool _dismissed = false;

  /// 삭제로 확정되는 거리 (카드 폭 대비). 절반이면 한 손 엄지로 닿는다
  static const _threshold = 0.4;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _onDismissed(DismissDirection _) {
    setState(() => _dismissed = true);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    // 스와이프는 스크린리더로 할 수 없다 — 같은 동작을 접근성 액션으로도 연다
    //
    // `container` 가 없으면 액션이 부모 노드로 합쳐져 카드 한 장의 동작이
    // 아니라 화면 전체의 동작이 된다
    return Semantics(
      container: true,
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.semanticLabel): widget.onDelete,
      },
      child: Dismissible(
        // 자식이 하나뿐이라 유일성은 필요 없다. 다만 위젯이 다시 만들어질 때
        // 바뀌는 키(ObjectKey 등)를 쓰면 미는 도중 상태가 초기화된다
        key: const ValueKey('swipe-delete'),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: _threshold},
        // 놓았을 때 확정·복귀가 끊기지 않도록 기본보다 약간 느긋하게
        movementDuration: const Duration(milliseconds: 260),
        resizeDuration: const Duration(milliseconds: 220),
        onUpdate: (details) => _progress.value = details.progress,
        onDismissed: _onDismissed,
        background: _DeleteBackground(progress: _progress),
        child: widget.child,
      ),
    );
  }
}

/// 밀었을 때 카드 뒤에 드러나는 삭제 배경.
///
/// 처음에는 은은하다가 확정 거리에 가까워질수록 진해지고 아이콘이 커진다 —
/// "여기까지 밀면 지워진다"가 손끝에서 읽힌다.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) {
        // 확정 거리에서 1 이 되도록 정규화한다
        final t = (value / _SwipeToDeleteState._threshold).clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.14 + 0.5 * t),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Transform.scale(
                scale: 0.85 + 0.3 * t,
                child: Icon(
                  Icons.delete_outlined,
                  size: AppIconSize.standard,
                  // 진해진 배경 위에서는 아이콘이 배경색과 섞이므로 밝게 바꾼다
                  color: Color.lerp(AppColors.danger, AppColors.textPrimary, t),
                ),
              ),
            ),
          ),
        );
      },
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
  AppLocalizations l10n,
) => switch (direction) {
  AlertDirection.enter => (
    Icons.login_outlined,
    l10n.placeDirectionEnter,
    semantic.alertEnter,
  ),
  AlertDirection.exit => (
    Icons.logout_outlined,
    l10n.placeDirectionExit,
    semantic.alertExit,
  ),
  AlertDirection.both => (
    Icons.sync_alt_outlined,
    l10n.placeDirectionBoth,
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
  // await 뒤에는 context 를 믿을 수 없다 — 먼저 잡아둔다
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final actions = ref.read(placeActionsProvider.notifier);

  final deleted = await actions.delete(place.id);
  if (deleted == null) return;
  showPlaceDeletedSnack(messenger, l10n, actions, deleted);
}

/// "삭제됨 · 되돌리기" 안내.
///
/// 편집 화면에서 지울 때는 화면이 먼저 닫히므로 `BuildContext` 를 쓸 수
/// 없다. 그래서 messenger 를 받는 형태로 분리했다 — 앱 최상단의
/// `ScaffoldMessenger` 는 화면이 닫혀도 남아 안내가 이전 화면 위에 뜬다.
void showPlaceDeletedSnack(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  PlaceActions actions,
  AlertPlace deleted,
) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.placeDeleted(deleted.name)),
        action: SnackBarAction(
          label: l10n.placeUndo,
          onPressed: () => actions.restore(deleted),
        ),
      ),
    );
}
