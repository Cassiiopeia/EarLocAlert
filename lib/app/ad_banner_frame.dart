import 'package:flutter/material.dart';

import '../features/ads/presentation/ad_banner_slot.dart';

/// 화면 아래에 배너를 붙이는 틀 (이슈 #186)
///
/// **화면이 광고를 모른다** — `places`·`settings` 는 `ads` 를 import 하지
/// 않고, 라우트를 만드는 `app` 이 이 틀로 감싼다 (docs/02-ARCHITECTURE.md 규칙 1).
///
/// 배너는 화면 **밖의** 띠다. 시트·버튼·지도가 배너 위로 밀려 올라가므로
/// 눌림 요소와 겹치지 않는다. 우발적 클릭은 계정 정지 사유다.
/// 알림·해제 완료·위치 선택 지도·온보딩 라우트는 감싸지 않는다.
class AdBannerFrame extends StatefulWidget {
  const AdBannerFrame({super.key, required this.child, this.slotBuilder});

  final Widget child;

  /// 테스트에서 실제 광고 SDK 대신 끼워 넣는다
  final Widget Function(ValueChanged<bool> onLoadedChanged)? slotBuilder;

  @override
  State<AdBannerFrame> createState() => _AdBannerFrameState();
}

class _AdBannerFrameState extends State<AdBannerFrame> {
  bool _loaded = false;

  void _onLoadedChanged(bool loaded) {
    if (_loaded != loaded && mounted) setState(() => _loaded = loaded);
  }

  @override
  Widget build(BuildContext context) {
    // 키보드가 올라오면 숨긴다 — 입력 중에 광고가 화면을 먹으면 안 된다
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bannerShown = _loaded && !keyboardOpen;

    return Column(
      children: [
        Expanded(
          // 배너가 아래 안전 영역을 차지하므로 화면은 그 여백을 또 주지 않는다.
          // 배너가 없을 때는 그대로 둬야 제스처 바에 가리지 않는다
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: bannerShown,
            // 화면 높이를 **배너를 뺀 실제 높이**로 알려준다. 홈의 시트와 지도 여백은
            // `MediaQuery` 높이에 비율을 곱해 계산하는데, 전체 높이를 그대로 주면
            // 시트는 줄어든 영역 기준, 지도 여백은 전체 기준이라 서로 어긋난다
            child: LayoutBuilder(
              builder: (context, constraints) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: bannerShown
                      ? media.copyWith(
                          size: Size(media.size.width, constraints.maxHeight),
                        )
                      : media,
                  child: widget.child,
                );
              },
            ),
          ),
        ),
        // Offstage 로 두는 이유: 키보드가 닫혔을 때 광고를 다시 요청하지 않는다
        Offstage(
          offstage: keyboardOpen,
          child:
              widget.slotBuilder?.call(_onLoadedChanged) ??
              AdBannerSlot(onLoadedChanged: _onLoadedChanged),
        ),
      ],
    );
  }
}
