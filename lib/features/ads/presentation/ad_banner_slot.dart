import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/ad_unit_ids.dart';
import 'ads_providers.dart';

/// 화면 맨 아래 고정 배너 한 칸 (이슈 #186)
///
/// **이 위젯은 실패하면 아무것도 그리지 않는다.** 광고가 화면을 깨뜨리거나
/// 빈 띠를 남기면 안 된다 (docs/02-ARCHITECTURE.md 규칙 4). 로드가 끝나야
/// 높이가 생기고, 그때 [onLoadedChanged] 로 부모에게 알린다.
///
/// 동의가 확정되기 전에는 요청하지 않는다 (이슈 #166). 동의 화면은 앱 시작
/// 직후 뜨므로, 아직 준비되지 않았으면 잠시 뒤 다시 묻는다.
class AdBannerSlot extends ConsumerStatefulWidget {
  const AdBannerSlot({super.key, required this.onLoadedChanged});

  /// 배너가 실제로 그려지는 상태가 바뀔 때 알린다
  final ValueChanged<bool> onLoadedChanged;

  @override
  ConsumerState<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends ConsumerState<AdBannerSlot> {
  /// 동의 대기 재시도 — 무한히 두드리지 않는다
  static const _maxConsentRetries = 3;
  static const _consentRetryDelay = Duration(seconds: 8);

  BannerAd? _ad;
  AdSize? _size;
  Timer? _retry;
  bool _requested = false;
  int _consentRetries = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 폭이 정해진 뒤 한 번만 요청한다. 화면 회전에 따른 재요청은 하지 않는다
    if (_requested) return;
    _requested = true;
    unawaited(_load(MediaQuery.sizeOf(context).width.truncate()));
  }

  Future<void> _load(int width) async {
    try {
      if (!await ref.read(adConsentProvider).canRequestAds()) {
        if (_consentRetries++ < _maxConsentRetries && mounted) {
          Diagnostics.log('ads', 'banner skipped reason=consent_not_ready');
          _retry = Timer(_consentRetryDelay, () => _load(width));
        }
        return;
      }
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (size == null || !mounted) return;

      final ad = BannerAd(
        adUnitId: AdUnitIds.banner,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (loaded) {
            if (!mounted) {
              loaded.dispose();
              return;
            }
            Diagnostics.log(
              'ads',
              'banner loaded size=${size.width}x${size.height}',
            );
            setState(() => _size = size);
            widget.onLoadedChanged(true);
          },
          onAdFailedToLoad: (failed, error) {
            // 사유를 남긴다 — 광고가 안 뜨는 이유의 유일한 단서다
            Diagnostics.log(
              'ads',
              'banner failed code=${error.code} message=${error.message}',
            );
            failed.dispose();
            if (mounted) {
              setState(() {
                _ad = null;
                _size = null;
              });
              widget.onLoadedChanged(false);
            }
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } on Object catch (error) {
      Diagnostics.log('ads', 'banner load error $error');
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _size;
    if (ad == null || size == null) return const SizedBox.shrink();

    // 앱 콘텐츠와 색·선으로 갈라 광고임을 알아보게 한다. 눌림 요소와 붙지 않는다
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.bgElevated)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: size.height.toDouble(),
          child: Center(
            child: SizedBox(
              width: size.width.toDouble(),
              height: size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        ),
      ),
    );
  }
}
