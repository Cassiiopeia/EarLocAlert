part of '../place_map_home_screen.dart';

// 알림 약함 경고 배너

/// 알림이 약할 때 뜨는 경고 (이슈 #74, #115)
///
/// **눈에 띄어야 한다.** 예전에는 회색 알약에 한 줄이라 지도 위에서 그냥
/// 묻혔고, 문구도 잘려서 무엇이 문제인지 읽히지 않았다. 이 배너를 놓치면
/// 사용자는 절전 중에 알림을 못 받고도 이유를 모른다.
///
/// 다만 **고장은 아니다.** 알림은 오고 있고 이걸 켜면 확실해진다는 뜻이라,
/// 감시가 아예 안 도는 상태(빨강)와는 색을 구분한다.
class _WeakAlertBanner extends StatelessWidget {
  const _WeakAlertBanner({required this.onTap, this.missing = const []});

  final VoidCallback onTap;

  /// 아직 켜지지 않은 항목 이름. 비어 있으면 일반 문구로 떨어진다.
  ///
  /// **무엇이 빠졌는지 말해주는 것이 핵심이다** — "알림이 약합니다"만으로는
  /// 무엇을 해야 할지 알 수 없다.
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.warning;

    // **불투명해야 한다.** 지도 위에 뜨는 배너라 반투명이면 도로와 지명이
    // 글자 뒤로 비쳐 읽히지 않는다. 표면색에 강조색을 섞어 경고 기운은
    // 남기되 바탕은 가린다
    return Material(
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.22),
        context.appColors.surface,
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.placeHomeWeakTitle,
                      style: context.appTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // 조사를 붙이지 않는다 — 항목 이름이 바뀔 때마다
                      // 은/는·이/가가 어긋난다
                      context.keepAllText(
                        missing.isEmpty
                            ? context.l10n.placeHomeWeakPowerSaving
                            : context.l10n.placeHomeWeakMissing(
                                missing.join(' · '),
                              ),
                      ),
                      style: context.appTextStyles.caption,
                      // **두 줄까지 보여준다** — 한 줄로 자르면 정작 무엇이
                      // 꺼졌는지가 잘려 나간다
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_outlined, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
