import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/text/keep_all.dart';
import '../domain/place_validator.dart';

/// 빈 상태 — 앱 첫인상을 결정한다.
///
/// "장소가 없다"가 아니라 **무엇을 하면 되는지**를 말한다.
class PlaceEmptyState extends StatelessWidget {
  const PlaceEmptyState({
    required this.onAddPlace,
    this.compact = false,
    super.key,
  });

  final VoidCallback onAddPlace;

  /// 지도 홈의 시트 안처럼 세로 공간이 좁을 때
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 시트 안에서는 손잡이 바로 아래에서 시작한다 (이슈 #228) — 손잡이가
      // 이미 위 여백을 갖고 있어 한 칸 더 띄우면 내용이 가라앉아 보인다
      padding: compact
          ? const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            )
          : const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            const Icon(
              Icons.add_location_alt_outlined,
              size: AppIconSize.hero,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            context.l10n.placeEmptyTitle,
            // 시트 안에서는 다른 시트 제목과 같은 굵은 본문 — 아래 회색 설명과
            // 크기가 비슷해 굵기로 위계를 세운다 (docs/06-UX.md 타이포)
            style: compact
                ? AppTypography.body.copyWith(fontWeight: FontWeight.w600)
                : AppTypography.screenTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.keepAllText(context.l10n.placeEmptyBody),
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          FilledButton(
            onPressed: onAddPlace,
            child: Text(context.l10n.placeEmptyAction),
          ),
        ],
      ),
    );
  }
}

/// 검증 오류를 사용자 문구로 바꾼다
String placeErrorMessage(AppLocalizations l10n, PlaceValidationError error) =>
    switch (error) {
      PlaceValidationError.emptyName => l10n.placeErrorEmptyName,
      PlaceValidationError.radiusOutOfRange => l10n.placeErrorRadius(
        PlaceValidator.minRadiusMeters,
        PlaceValidator.maxRadiusMeters,
      ),
      PlaceValidationError.invalidCoordinates => l10n.placeErrorCoordinates,
      PlaceValidationError.limitReached => l10n.placeErrorLimit(
        PlaceValidator.maxPlaces,
      ),
      PlaceValidationError.emptyScheduleWindow => l10n.placeErrorEmptyWindow,
      PlaceValidationError.scheduleWithoutDays => l10n.placeErrorNoDays,
    };
