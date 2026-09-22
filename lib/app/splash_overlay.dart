import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/theme/app_colors.dart';
import '../features/alert/presentation/alert_controller_provider.dart';

/// 네이티브 스플래시에서 앱으로 넘어오는 순간을 잇는다 (이슈 #150)
///
/// 네이티브 스플래시는 Flutter 의 첫 프레임에 사라진다. 지금은 정지한
/// 핀이 그 자리에서 딱 끊기고 화면이 바뀐다. 같은 배경·같은 핀을 이어
/// 그려 숨 한 번 내쉬듯 걷히게 한다.
///
/// **하지 않는 쪽으로 기우는 설계다.** 이어 그리지 못할 사정이 하나라도
/// 있으면 애니메이션을 통째로 버리고 지금까지처럼 네이티브 스플래시가
/// 그대로 걷히게 둔다. 어설프게 이으면 없느니만 못하다.
///
/// 버리는 경우가 셋이다.
///
/// | 사정 | 왜 |
/// |---|---|
/// | 시작 시점에 알림 세션이 있다 | 앱이 죽었다 살아난 경로 (이슈 #130) |
/// | 도중에 알림이 승격됐다 | 대개의 알림 경로 — 부트스트랩이 첫 프레임 뒤에 돈다 |
/// | 핀 디코드가 안 끝났다 | 핀 없는 검은 판이 번쩍인다 |
///
/// 알림을 두 곳에서 막는 것은 **알림이 언제 서느냐가 다르기** 때문이다.
/// 한쪽만 막으면 나머지 한쪽에서 알림 화면이 반 초 늦는다 — 버스에서
/// 급히 끄려는 사람에게 그 시간은 길다
/// (docs/02-ARCHITECTURE.md 규칙 4 와 같은 이유).
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({required this.child, super.key});

  final Widget child;

  static const _asset = 'assets/splash/splash_logo.png';

  /// 핀 디코드가 끝났는가. 끝나지 않았으면 애니메이션을 하지 않는다.
  @visibleForTesting
  static bool isWarm = false;

  /// 핀을 미리 디코드한다 — `runApp` 전에 부른다.
  ///
  /// **여기서 기다리는 동안 화면에는 네이티브 스플래시가 떠 있다.** 빈
  /// 화면이 보이는 대기가 아니다. 반대로 데우지 않으면 `Image.asset` 이
  /// 디코드 전까지 아무것도 내놓지 않아, 핀 자리에 검은 판만 남는다.
  ///
  /// [budget] 안에 못 끝내면 포기한다. 스플래시 그림 한 장 때문에 앱이
  /// 늦게 뜨는 것은 본말전도다.
  static Future<void> warmUp({
    Duration budget = const Duration(milliseconds: 600),
  }) async {
    final done = Completer<void>();
    final stream = const AssetImage(_asset).resolve(ImageConfiguration.empty);
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final listener = ImageStreamListener(
      (_, _) => finish(),
      onError: (_, _) => finish(),
    );
    stream.addListener(listener);
    try {
      await done.future.timeout(budget);
      isWarm = true;
    } on Object {
      // 못 데워도 앱은 뜬다 — 애니메이션만 생략된다
    } finally {
      stream.removeListener(listener);
    }
  }

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with SingleTickerProviderStateMixin {
  /// 짧게 잡는다. 잔잔한 것과 느린 것은 다르다 — 매 실행에 붙는 시간이다.
  /// 실기기에서는 프레임이 밀려 이보다 조금 더 걸린다.
  static const _duration = Duration(milliseconds: 520);

  /// 핀 판이 화면 짧은 변에서 차지하는 비율.
  ///
  /// 네이티브 스플래시가 그리는 핀에 맞춘 값이다. 실기기에서 네이티브
  /// 158×232px(@1080) 에 맞춰 역산했다 — 어긋나면 넘어오는 순간 핀이
  /// 튄다. 이으려고 넣은 것이 오히려 끊겨 보인다.
  static const _logoFraction = 0.372;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  @override
  void initState() {
    super.initState();
    if (ref.read(activeAlertProvider) != null) {
      _cutShort('시작 시점에 알림 세션 있음');
      return;
    }
    if (!SplashOverlay.isWarm) {
      _cutShort('핀 디코드 전');
      return;
    }
    // **첫 프레임이 그려진 뒤에 시작한다.** `initState` 에서 바로 돌리면
    // 화면에는 아직 네이티브 스플래시가 덮여 있는 동안 애니메이션이
    // 끝나버린다 — 로그에는 실행됐다고 남는데 눈에는 아무것도 안 보인다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.isCompleted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 애니메이션을 끝으로 밀어 즉시 걷는다.
  void _cutShort(String reason) {
    if (_controller.isCompleted) return;
    Diagnostics.log('splash', '전환 애니메이션 생략 사유=$reason');
    _controller.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    // 승격은 첫 프레임 뒤 부트스트랩에서 일어난다 — 그 순간 걷는다
    ref.listen(activeAlertProvider, (_, next) {
      if (next != null) _cutShort('대기 알림 승격');
    });

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // 다 걷힌 뒤에는 트리에서 뺀다 — 투명해도 남으면 탭을 먹는다
            if (_controller.isCompleted) return const SizedBox.shrink();
            return IgnorePointer(child: _curtain(context));
          },
        ),
      ],
    );
  }

  Widget _curtain(BuildContext context) {
    final t = _controller.value;
    // 끝 45% 에서만 옅어진다 — 시작하자마자 걷히면 이어진 느낌이 없다
    final fade = Curves.easeInOut.transform(
      ((t - 0.55) / 0.45).clamp(0.0, 1.0),
    );
    // 아주 조금만 커진다. 눈에 띄면 잔잔한 것이 아니다
    final scale = 1 + 0.06 * Curves.easeOutCubic.transform(t);

    final side = MediaQuery.sizeOf(context).shortestSide;

    return Opacity(
      opacity: 1 - fade,
      child: ColoredBox(
        color: AppColors.bgBase,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              SplashOverlay._asset,
              width: side * _logoFraction,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
