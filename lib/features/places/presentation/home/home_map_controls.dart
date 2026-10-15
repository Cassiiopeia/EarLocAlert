part of '../place_map_home_screen.dart';

// 지도 위 조작 버튼(내 위치·장소 추가)

/// 장소 추가 버튼 — 시트 높이를 따라 움직인다.
///
/// 고정해두면 시트를 올렸을 때 버튼이 그 아래로 숨는다.
/// 지도 위에 떠 있는 버튼들 (이슈 #155)
///
/// **오른쪽 가장자리에 세로로 쌓는다.** 예전에는 내 위치가 왼쪽, 장소
/// 추가가 오른쪽으로 갈려 있었는데, 그건 "오른쪽 아래를 장소 추가가 이미
/// 쓰고 있어서" 밀려난 결과지 그 자리가 나아서가 아니었다.
///
/// 한쪽에 모으는 이유는 **엄지가 닿는 쪽**이기 때문이다. 이 앱은 버스에서
/// 한 손으로 쓴다 — 오른손잡이가 왼쪽 버튼을 누르려면 화면을 가로질러야
/// 하고, 그 동작이 그대로 지도를 건드려 카메라를 움직인다.
///
/// 왼쪽을 비우면 지도도 그만큼 넓게 열린다. 갈라 두면 양쪽이 다 좁다.
///
/// 시트 높이를 따라 함께 오르내린다 — 고정하면 시트를 올렸을 때 아래로
/// 숨는다.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.bottomFraction,
    required this.onMyLocation,
    required this.onAddPlace,
  });

  final double bottomFraction;
  final VoidCallback onMyLocation;
  final VoidCallback onAddPlace;

  @override
  Widget build(BuildContext context) {
    // 시트를 끝까지 올리면 버튼이 시트를 따라 상단 막대까지 올라가 설정 버튼을
    // 덮었다 — 설정을 누르면 장소 등록이 열렸다 (#280). 닿으면 숨기고 눌리지
    // 않게 한다. 시트를 내리면 다시 나타난다
    final hidden = mapControlsReachTopBar(
      screenHeight: MediaQuery.sizeOf(context).height,
      sheetFraction: bottomFraction,
      topSafePadding: MediaQuery.paddingOf(context).top,
    );

    // 보조(내 위치 48)가 위, 주(장소 추가 56)가 아래 — 엄지에 가장 가까운
    // 자리를 주 동작이 쓴다. 둘 다 원이고 **세로 중심을 맞춘다**
    // (디자인 리뷰 #155 — 예전엔 크기·모양이 다르고 오른쪽 끝에 붙어 어긋나
    // 보였다).
    //
    // 두 버튼 모두 보이는 원보다 [_slop] 만큼 넓게 눌린다. 넓힌 만큼 바깥
    // 여백에서 빼 보이는 자리는 그대로이고, 두 버튼 사이 틈(xs)은 반씩
    // 나눠 서로의 범위가 겹치지 않는다
    const gapHalf = AppSpacing.xs / 2;
    return Positioned(
      right: AppSpacing.sm - _slop,
      bottom:
          MediaQuery.sizeOf(context).height * bottomFraction +
          AppSpacing.sm -
          _slop,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingCircleButton(
                icon: Icons.my_location_outlined,
                onPressed: onMyLocation,
                semanticLabel: context.l10n.placeMyLocation,
                slop: const EdgeInsets.fromLTRB(_slop, _slop, _slop, gapHalf),
              ),
              FloatingCircleButton(
                icon: Icons.add_outlined,
                onPressed: onAddPlace,
                semanticLabel: context.l10n.placeHomeAddPlace,
                size: AppControlSize.primary,
                background: context.appColors.accent,
                foreground: context.appColors.onAccent,
                slop: const EdgeInsets.fromLTRB(_slop, gapHalf, _slop, _slop),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지도 위 버튼 묶음(내 위치 48 + 틈 8 + 장소 추가 56)이 상단 막대에 닿는가 (#280)
///
/// 버튼은 시트 윗변에서 [AppSpacing.sm] 위에 선다. 상단 막대는 안전 영역 아래
/// [AppSpacing.sm] 여백 + 높이 [AppControlSize.floating] 이고, 그 아래로 한 칸
/// 더 띄워야 겹쳐 보이지 않는다.
@visibleForTesting
bool mapControlsReachTopBar({
  required double screenHeight,
  required double sheetFraction,
  required double topSafePadding,
}) {
  const controlsHeight =
      AppControlSize.floating + AppSpacing.xs + AppControlSize.primary;
  final controlsTop =
      screenHeight -
      (screenHeight * sheetFraction + AppSpacing.sm) -
      controlsHeight;
  final topBarBottom =
      topSafePadding + AppSpacing.sm + AppControlSize.floating + AppSpacing.sm;
  return controlsTop < topBarBottom;
}

/// 떠 있는 버튼이 보이는 모양보다 넓게 받는 폭
const double _slop = AppSpacing.xs;
