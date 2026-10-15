part of '../place_form_screen.dart';

// 고른 위치와 반경을 보여주는 지도 미리보기

/// 고른 위치를 보여주는 지도 카드 (이슈 #155)
///
/// **핀은 가운데 고정이고 반경만 움직인다.** 슬라이더를 조절하면 원이
/// 커지고 줌이 따라 나간다 — 그래야 "800m 가 실제로 어디까지인지"가 보인다.
///
/// **lite mode 를 쓰지 않는다.** 알림 화면 카드(결정 033)는 전력 때문에
/// lite 를 골랐지만 그것은 정적 스냅샷이라 줌이 따라가야 하는 이 화면과
/// 맞지 않는다. 대신 조작을 전부 끈다 — 폼 스크롤을 지도가 먹으면 안 되고,
/// 위치를 바꾸는 길은 탭해서 지도 선택으로 가는 하나뿐이어야 한다.
class _LocationPreview extends StatefulWidget {
  const _LocationPreview({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.onTap,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final VoidCallback? onTap;

  @override
  State<_LocationPreview> createState() => _LocationPreviewState();
}

class _LocationPreviewState extends State<_LocationPreview> {
  static const double _height = 168;

  GoogleMapController? _map;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LocationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    final resized = oldWidget.radiusMeters != widget.radiusMeters;
    if (moved || resized) _syncCamera();
  }

  /// 반경이 바뀌면 줌을 맞춘다.
  ///
  /// `moveCamera` 를 쓴다 — 슬라이더를 끄는 동안 매 프레임 애니메이션이
  /// 걸리면 카메라가 밀린다.
  void _syncCamera() {
    _map?.moveCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(widget.latitude, widget.longitude),
        zoomForRadiusWider(widget.radiusMeters),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final target = LatLng(widget.latitude, widget.longitude);

    return GestureDetector(
      // **opaque 가 없으면 탭이 아무 데도 닿지 않는다.** 기본값(deferToChild)
      // 은 자식이 맞아야 반응하는데, 자식이 지도·마스크 둘 다 IgnorePointer
      // 라 hit test 가 통째로 비었다. 실기기에서 네 번 눌러도 지도 선택이
      // 열리지 않았다 (이슈 #155 QA)
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      // 카드와 같은 모서리 (이슈 #228). iOS 는 네이티브 지도도 클립이 먹고,
      // 안 먹는 Android 는 아래 마스크가 덮는다 — 둘 다 같은 반경이어야 한다
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 지도는 조작을 받지 않는다 — 탭은 위의 GestureDetector 가 받는다
              IgnorePointer(
                child: MapRevealCover(
                  screen: 'form',
                  builder: (attach) => GoogleMap(
                    onMapCreated: (controller) {
                      _map = controller;
                      // 다크 스타일이 조용히 사라지는 일이 있다 (이슈 #143)
                      unawaited(
                        ensureMapStyle(
                          controller,
                          'form',
                          style: MapStyle.jsonForBrightness(
                            Theme.of(context).brightness,
                          ),
                        ),
                      );
                      // 다크 타일이 그려질 때까지 밝은 바탕을 가린다 (이슈 #143)
                      attach(controller);
                    },
                    initialCameraPosition: CameraPosition(
                      target: target,
                      zoom: zoomForRadiusWider(widget.radiusMeters),
                    ),
                    style: MapStyle.jsonForBrightness(
                      Theme.of(context).brightness,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('picked'),
                        position: target,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueCyan,
                        ),
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('radius'),
                        center: target,
                        radius: widget.radiusMeters,
                        strokeWidth: 2,
                        strokeColor: semantic.alertEnter,
                        fillColor: semantic.alertEnter.withValues(alpha: 0.12),
                      ),
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
              ),
              // `ClipRRect` 가 네이티브 지도 뷰를 자르지 못한다 (이슈 #142)
              IgnorePointer(
                child: CustomPaint(
                  painter: MapCornerMask(
                    color: context.appColors.background,
                    radius: AppRadius.card,
                  ),
                ),
              ),
              // 카드 윤곽선 (이슈 #228). 다크 지도의 땅 색이 화면 배경과 거의
              // 같아 둥글게 잘라도 모서리가 보이지 않았다 — 도로만 가장자리까지
              // 뻗어 각진 판처럼 읽혔다. 한 층 밝은 선으로 카드 경계를 그린다
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.appColors.elevated),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 방향 버튼 라벨 — 한 줄을 지킨다 (이슈 #224)
///
/// 세 칸으로 나눈 폭이 좁아 영어 "Departure" 가 "Departur / e" 로 단어
/// 중간에서 쪼개졌다. 줄을 바꾸지 않고, 넘치면 글자를 조금 줄인다.
