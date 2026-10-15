part of '../place_map_home_screen.dart';

// 장소 목록 시트와 설정 버튼

/// 하단 시트 — 등록한 장소 목록
class _PlaceSheet extends ConsumerWidget {
  const _PlaceSheet({
    required this.scrollController,
    required this.places,
    required this.loading,
    required this.failed,
    required this.selectedPlaceId,
    required this.onAddPlace,
    this.onEditPlace,
  });

  final ScrollController scrollController;
  final List<AlertPlace> places;
  final bool loading;
  final bool failed;
  final String? selectedPlaceId;
  final VoidCallback onAddPlace;
  final void Function(AlertPlace place)? onEditPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: Column(
        children: [
          // 손잡이 — 이 시트가 끌어올려진다는 유일한 단서다
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.textSecondary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Expanded(child: _buildPlaceListOrEmptyState(context, ref)),
        ],
      ),
    );
  }

  Widget _buildPlaceListOrEmptyState(BuildContext context, WidgetRef ref) {
    // **여백을 직접 정한다** (이슈 #228). `ListView` 는 padding 이 없으면
    // 화면의 안전 영역(상태바 높이)을 위 여백으로 넣는다 — 이 목록은 화면
    // 맨 아래 시트 안이라 상태바와 무관한데, 빈 화면 문구가 손잡이 아래로
    // 50pt 넘게 밀려 내려갔다. 아래쪽만 홈 인디케이터만큼 비운다
    final messagePadding = EdgeInsets.only(
      bottom: MediaQuery.paddingOf(context).bottom,
    );

    if (failed) {
      return ListView(
        controller: scrollController,
        padding: messagePadding,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              context.l10n.placeHomeLoadFailed,
              style: context.appTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (loading && places.isEmpty) {
      return ListView(
        controller: scrollController,
        padding: messagePadding,
        children: const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (places.isEmpty) {
      // 스크롤 가능해야 시트를 끌어내릴 수 있다
      return ListView(
        controller: scrollController,
        padding: messagePadding,
        children: [PlaceEmptyState(onAddPlace: onAddPlace, compact: true)],
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final place = places[index];
        return PlaceCard(
          // 지우거나 되돌릴 때 카드가 자리를 옮긴다 — 장소로 짝지어야 상태가
          // 다른 카드로 넘어가지 않는다 (#274)
          key: ValueKey(place.id),
          place: place,
          selected: place.id == selectedPlaceId,
          onTap: () => onEditPlace?.call(place),
          onToggle: (enabled) => ref
              .read(placeActionsProvider.notifier)
              .setEnabled(place.id, enabled: enabled),
          onDelete: () => deletePlaceWithUndo(context, ref, place),
        );
      },
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  /// 보이는 원 바깥으로 더 받는 폭
  static const double slop = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    // 떠 있는 버튼은 한 규격으로 (디자인 리뷰 #155) — 모양·크기·탭 범위를
    // 공용 버튼이 정한다. 예전 38×34dp 원은 최소 터치 타깃에도 못 미쳤다
    return FloatingCircleButton(
      icon: Icons.settings_outlined,
      onPressed: onPressed,
      semanticLabel: context.l10n.placeHomeSettings,
    );
  }
}

/// 내 위치에서 시작해도 되는가 (이슈 #218)
///
/// 장소가 있으면 장소가 보이는 것이 먼저다. 이미 카메라를 장소에 맞췄다면 늦게 도착한
/// 위치 조회가 그것을 덮어쓰면 안 된다.
@visibleForTesting
bool shouldStartAtCurrentLocation({
  required bool hasPlaces,
  required bool didFitCamera,
}) => !hasPlaces && !didFitCamera;
