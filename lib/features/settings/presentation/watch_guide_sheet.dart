import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';

/// 안내가 어느 플랫폼 기준인지 (이슈 #270)
///
/// 워치 알림을 켜는 곳이 플랫폼마다 달라(Android 는 Galaxy Wearable 같은 워치
/// 앱, iOS 는 Watch 앱) 문구가 갈린다. `dart:io` 를 화면이 직접 보지 않도록
/// app 계층이 값으로 내려준다.
enum WatchGuidePlatform { android, ios }

/// 워치로 알림 받는 방법 안내 시트 (이슈 #270)
///
/// 워치 연결 여부는 감지하지 않는다 — 라이브러리와 권한이 늘고, 못 읽어도 안내가
/// 틀리지 않기 때문이다. 확인을 누르면 닫히고, 반환값은 없다.
Future<void> showWatchGuideSheet(
  BuildContext context, {
  required WatchGuidePlatform platform,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => WatchGuideSheet(platform: platform),
  );
}

class WatchGuideSheet extends StatelessWidget {
  const WatchGuideSheet({required this.platform, super.key});

  final WatchGuidePlatform platform;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appName = l10n.appName;
    final steps = switch (platform) {
      WatchGuidePlatform.android => [
        l10n.watchGuideAndroidStep1,
        l10n.watchGuideAndroidStep2,
        l10n.watchGuideAndroidStep3(appName),
      ],
      WatchGuidePlatform.ios => [
        l10n.watchGuideIosStep1,
        l10n.watchGuideIosStep2,
        l10n.watchGuideIosStep3(appName),
      ],
    };

    // 글자를 크게 키운 기기에서는 시트 높이를 넘는다 — 넘치지 않고 스크롤되게 한다
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.watch_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.settingsWatchTitle,
                      style: context.appTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.keepAllText(l10n.watchGuideIntro),
                style: context.appTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 번호 알약 — 순서대로 따라 하는 안내라는 것이 한눈에 보인다
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.appColors.elevated,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: context.appTextStyles.caption,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          context.keepAllText(steps[i]),
                          style: context.appTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.keepAllText(l10n.watchGuideNote),
                style: context.appTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.watchGuideConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
