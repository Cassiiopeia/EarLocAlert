import 'package:flutter/material.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/alert_session.dart';
import '../domain/audio_route.dart';

/// 알림 화면 (docs/06-UX.md)
///
/// **이 앱의 사용 시간 99% 가 이 화면이다.**
///
/// 설계 전제:
/// - 버스 안, 한 손으로, 졸다 깬 직후
/// - 주변에 사람이 있어 소리를 낼 수 없다
/// - 몇 초 안에 꺼야 한다는 압박
///
/// 그래서 해제 버튼이 화면 하단 절반을 차지하고, **누를 수 있는 것이
/// 그것 하나뿐**이다. 스와이프를 쓰지 않는다 (docs/10-DECISIONS.md 016).
class AlertScreen extends StatelessWidget {
  const AlertScreen({
    required this.session,
    required this.onDismiss,
    this.soundFailed = false,
    super.key,
  });

  final AlertSession session;
  final VoidCallback onDismiss;

  /// 소리를 내려 했으나 실패해 진동으로 떨어졌는가
  final bool soundFailed;

  bool get _isExit => session.direction == AlertDirection.exit;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final accent = _isExit ? semantic.alertExit : semantic.alertEnter;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _AlertInfo(
                session: session,
                accent: accent,
                isExit: _isExit,
                soundFailed: soundFailed,
              ),
            ),
            // 하단 절반 — 보지 않고 엄지로 누를 수 있어야 한다
            Expanded(child: _DismissButton(onPressed: onDismiss)),
          ],
        ),
      ),
    );
  }
}

class _AlertInfo extends StatelessWidget {
  const _AlertInfo({
    required this.session,
    required this.accent,
    required this.isExit,
    required this.soundFailed,
  });

  final AlertSession session;
  final Color accent;
  final bool isExit;
  final bool soundFailed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 색만으로 구분하지 않는다 — 아이콘·텍스트를 함께 쓴다 (색각 이상 대응)
          Icon(
            isExit ? Icons.logout_outlined : Icons.login_outlined,
            size: 56,
            color: accent,
          ),
          const SizedBox(height: AppSpacing.md),

          // 가장 큰 글자 — 여러 곳을 등록했으면 "어디인지"가 첫 정보다
          Text(
            session.placeName,
            style: AppTypography.alertPlaceName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isExit ? '떠났습니다' : '도착했습니다',
            style: AppTypography.screenTitle.copyWith(color: accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_formatTime(session.startedAt), style: AppTypography.caption),

          const SizedBox(height: AppSpacing.lg),
          _AudioRouteBadge(route: session.audioRoute, soundFailed: soundFailed),
        ],
      ),
    );
  }

  /// 표시 직전에만 로컬 시각으로 바꾼다 (docs/04-CONVENTIONS.md)
  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final hour = local.hour;
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$period $displayHour:$minute';
  }
}

/// 오디오 경로 표시.
///
/// **이 앱을 쓰는 이유가 이것이다.** 사용자는 소리가 스피커로 새지 않았다는
/// 것을 확인하고 싶어 한다 (docs/06-UX.md).
class _AudioRouteBadge extends StatelessWidget {
  const _AudioRouteBadge({required this.route, required this.soundFailed});

  final AudioRoute route;
  final bool soundFailed;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final isHeadphones = route == AudioRoute.headphones;

    final label = switch ((isHeadphones, soundFailed)) {
      (true, _) => '이어폰으로 알림 중',
      (false, true) => '소리를 재생하지 못해 진동으로 알림 중',
      (false, false) => '진동으로만 알림 중',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHeadphones ? Icons.headphones_outlined : Icons.vibration_outlined,
            size: 18,
            color: isHeadphones
                ? semantic.audioBluetooth
                : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(label, style: AppTypography.caption)),
        ],
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox.expand(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
          child: Text(
            '알림 끄기',
            style: AppTypography.displayLarge.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
