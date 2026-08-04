import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            const Icon(
              Icons.add_location_alt_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            '첫 장소를 등록해보세요',
            style: compact ? AppTypography.body : AppTypography.screenTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '내릴 정류장, 약속 장소, 집 —\n도착하거나 떠날 때 조용히 알려드립니다.',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          FilledButton(onPressed: onAddPlace, child: const Text('장소 등록')),
        ],
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
