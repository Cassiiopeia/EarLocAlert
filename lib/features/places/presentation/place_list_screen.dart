import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/alert_place.dart';
import '../domain/place_validator.dart';
import 'place_list_controller.dart';

/// 위치 목록 화면 (docs/06-UX.md)
///
/// 활성 상태를 **배경 반전**으로 표현한다 — 어두운 목록 안의 밝은 카드.
/// 참조 미감(다크 핀테크)의 선택 표현을 그대로 따른다.
class PlaceListScreen extends ConsumerWidget {
  const PlaceListScreen({
    required this.onAddPlace,
    this.onEditPlace,
    this.onPreviewAlert,
    super.key,
  });

  final VoidCallback onAddPlace;
  final void Function(AlertPlace place)? onEditPlace;

  /// 알림 흐름 수동 확인 (실기기 스파이크 S-4·S-5 용).
  /// 지오펜스 연동이 끝나면 제거한다 (docs/11-ROADMAP.md).
  final VoidCallback? onPreviewAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(placeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 장소'),
        actions: [
          if (onPreviewAlert != null)
            IconButton(
              onPressed: onPreviewAlert,
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: '알림 미리보기',
            ),
        ],
      ),
      body: placesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('장소를 불러오지 못했습니다', style: AppTypography.caption)),
        data: (places) => places.isEmpty
            ? _EmptyState(onAddPlace: onAddPlace)
            : _PlaceList(places: places, onEditPlace: onEditPlace),
      ),
      floatingActionButton: placesAsync.valueOrNull?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              onPressed: onAddPlace,
              child: const Icon(Icons.add_outlined),
            ),
    );
  }
}

/// 빈 상태 — 앱 첫인상을 결정한다.
///
/// "장소가 없다"가 아니라 **무엇을 하면 되는지**를 말한다.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddPlace});

  final VoidCallback onAddPlace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.add_location_alt_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '첫 장소를 등록해보세요',
            style: AppTypography.screenTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '내릴 정류장, 약속 장소, 집 —\n도착하거나 떠날 때 조용히 알려드립니다.',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onAddPlace, child: const Text('장소 등록')),
        ],
      ),
    );
  }
}

class _PlaceList extends ConsumerWidget {
  const _PlaceList({required this.places, this.onEditPlace});

  final List<AlertPlace> places;
  final void Function(AlertPlace place)? onEditPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final place = places[index];
        return _PlaceCard(
          place: place,
          onTap: () => onEditPlace?.call(place),
          onToggle: (enabled) => ref
              .read(placeActionsProvider.notifier)
              .setEnabled(place.id, enabled: enabled),
          onDelete: () => _deleteWithUndo(context, ref, place),
        );
      },
    );
  }

  /// 삭제는 실수를 되돌릴 수 있어야 한다
  Future<void> _deleteWithUndo(
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
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final AlertPlace place;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final enabled = place.enabled;

    // 활성 = 반전 카드 (docs/06-UX.md — 선택 상태는 밝은 배경으로 반전)
    final background = enabled ? AppColors.bgInverse : AppColors.bgSurface;
    final foreground = enabled
        ? AppColors.textOnInverse
        : AppColors.textPrimary;
    final secondary = enabled
        ? AppColors.textOnInverse
        : AppColors.textSecondary;

    final (
      directionIcon,
      directionLabel,
      directionColor,
    ) = switch (place.direction) {
      AlertDirection.enter => (
        Icons.login_outlined,
        '도착 알림',
        semantic.alertEnter,
      ),
      AlertDirection.exit => (
        Icons.logout_outlined,
        '출발 알림',
        semantic.alertExit,
      ),
      AlertDirection.both => (
        Icons.sync_alt_outlined,
        '도착·출발',
        semantic.alertEnter,
      ),
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
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

/// 검증 오류를 사용자 문구로 바꾼다
String placeErrorMessage(PlaceValidationError error) => switch (error) {
  PlaceValidationError.emptyName => '이름을 입력해주세요',
  PlaceValidationError.radiusOutOfRange =>
    '반경은 ${PlaceValidator.minRadiusMeters}m ~ ${PlaceValidator.maxRadiusMeters}m 사이여야 합니다',
  PlaceValidationError.invalidCoordinates => '위치 좌표가 올바르지 않습니다',
  PlaceValidationError.limitReached =>
    '장소는 최대 ${PlaceValidator.maxPlaces}개까지 등록할 수 있습니다',
};
