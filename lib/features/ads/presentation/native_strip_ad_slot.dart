import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../domain/native_strip_ad_loader.dart';
import 'ads_providers.dart';

/// 화면 맨 아래 고정 한 줄 네이티브 광고 띠 (이슈 #283)
///
/// **이 위젯은 실패하면 아무것도 그리지 않는다.** 광고가 화면을 깨뜨리거나
/// 빈 띠를 남기면 안 된다 (docs/02-ARCHITECTURE.md 규칙 4). 로드가 끝나야
/// 높이가 생기고, 그때 [onLoadedChanged] 로 부모에게 알린다.
///
/// 동의가 확정되기 전에는 요청하지 않는다 (이슈 #166). 동의 화면은 앱 시작
/// 직후 뜨므로, 아직 준비되지 않았으면 잠시 뒤 다시 묻는다.
/// 색은 로드 때 네이티브에 넘기므로 라이트·다크가 바뀌면 다시 로드한다.
class NativeStripAdSlot extends ConsumerStatefulWidget {
  const NativeStripAdSlot({super.key, required this.onLoadedChanged});

  /// 띠 높이 (dp) — 네이티브 레이아웃은 이 높이에 맞춰 한 줄로 그린다
  static const double stripHeight = 44;

  /// 띠가 실제로 그려지는 상태가 바뀔 때 알린다
  final ValueChanged<bool> onLoadedChanged;

  @override
  ConsumerState<NativeStripAdSlot> createState() => _NativeStripAdSlotState();
}

class _NativeStripAdSlotState extends ConsumerState<NativeStripAdSlot> {
  /// 동의 대기 재시도 — 무한히 두드리지 않는다
  static const _maxConsentRetries = 3;
  static const _consentRetryDelay = Duration(seconds: 8);

  LoadedNativeStripAd? _loadedAd;
  Timer? _consentRetryTimer;
  Brightness? _requestedBrightness;
  int _consentRetryCount = 0;

  /// 테마가 바뀌면 올라가는 값 — 이전 요청의 늦은 응답을 버린다
  int _requestGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 첫 빌드와 라이트·다크 전환 때만 요청한다. 같은 테마의 재빌드는 무시
    final brightness = Theme.of(context).brightness;
    if (brightness == _requestedBrightness) return;
    _requestedBrightness = brightness;
    _consentRetryTimer?.cancel();
    _consentRetryCount = 0;
    unawaited(_load(_colorsOf(context), ++_requestGeneration));
  }

  /// 앱 색 토큰 > 띠 색 (앱 콘텐츠와 색으로 갈라 광고임을 알아보게 한다)
  NativeStripAdColors _colorsOf(BuildContext context) {
    final colors = context.appColors;
    return NativeStripAdColors(
      background: colors.surface.toARGB32(),
      headline: colors.textPrimary.toARGB32(),
      callToAction: colors.accent.toARGB32(),
      badgeBackground: colors.elevated.toARGB32(),
      badgeText: colors.textSecondary.toARGB32(),
    );
  }

  Future<void> _load(NativeStripAdColors colors, int generation) async {
    try {
      // 동의 확인 (확정 전 요청 금지, 모르면 잠시 뒤 재시도)
      if (!await ref.read(adConsentProvider).canRequestAds()) {
        if (_consentRetryCount++ < _maxConsentRetries && mounted) {
          Diagnostics.log(
            'ads',
            'native strip skipped reason=consent_not_ready',
          );
          _consentRetryTimer = Timer(
            _consentRetryDelay,
            () => _load(colors, generation),
          );
        }
        return;
      }
      final loadedAd = await ref.read(nativeStripAdLoaderProvider).load(colors);
      if (loadedAd == null) return;

      // 화면이 사라졌거나 더 새로운 요청이 있으면 버린다
      if (!mounted || generation != _requestGeneration) {
        loadedAd.dispose();
        return;
      }
      // 새 광고로 교체 (이전 광고는 트리에서 빠진 뒤 해제)
      final previousAd = _loadedAd;
      setState(() => _loadedAd = loadedAd);
      widget.onLoadedChanged(true);
      if (previousAd != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previousAd.dispose(),
        );
      }
    } on Object catch (error) {
      Diagnostics.log('ads', 'native strip load error $error');
    }
  }

  @override
  void dispose() {
    _consentRetryTimer?.cancel();
    _loadedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadedAd = _loadedAd;
    if (loadedAd == null) return const SizedBox.shrink();

    // 위 선으로 앱 콘텐츠와 갈라 눌림 요소와 붙지 않게 한다
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(top: BorderSide(color: context.appColors.elevated)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: NativeStripAdSlot.stripHeight,
          child: ref.watch(nativeStripAdViewBuilderProvider)(loadedAd),
        ),
      ),
    );
  }
}
