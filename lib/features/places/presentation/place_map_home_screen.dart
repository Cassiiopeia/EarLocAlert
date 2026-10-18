import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/map/default_map_view.dart';
import '../../../core/map/map_reveal_cover.dart';
import '../../../core/map/map_style_guard.dart';
import '../../../core/map/radius_zoom.dart';
import '../../../core/ui/foundation/alert_direction_appearance.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_semantic_colors.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../../../core/ui/foundation/map_style.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/status_bar_icons_following_theme.dart';
import '../../../core/ui/components/floating_circle_button.dart';
import '../domain/current_location_service.dart';
import '../domain/alert_place.dart';
import 'current_location_message.dart';
import 'place_card.dart';
import 'place_empty_state.dart';
import 'place_list_controller.dart';
import '../../../core/map/marker_hue.dart';
import '../../../core/ui/components/loading_indicator.dart';

// 화면 조각은 파일을 나눴다 (아키텍처 검수 #276 — 한 파일 1000줄 안팎)
part 'home/home_status_bar.dart';
part 'home/home_weak_alert_banner.dart';
part 'home/home_map_controls.dart';
part 'home/home_place_sheet.dart';

/// 메인 화면 (docs/06-UX.md "메인 화면")
///
/// **상태 바가 이 화면의 존재 이유다.** 지도는 예쁘라고 있는 게 아니라
/// "내가 등록한 게 여기 있고, 지금 감시 중이구나"를 확인시키기 위해 있다.
///
/// 감시 상태·이어폰 상태는 다른 feature 소유라 **값으로 받는다** —
/// 조립은 app 계층이 한다 (docs/02-ARCHITECTURE.md 규칙 1).
class PlaceMapHomeScreen extends ConsumerStatefulWidget {
  const PlaceMapHomeScreen({
    required this.isMonitoring,
    required this.isHeadphoneConnected,
    required this.onAddPlace,
    this.isStatusKnown = true,
    this.canAlertReliably = true,
    this.missingReliability = const [],
    this.onEditPlace,
    this.onFixMonitoring,
    this.onFixReliability,
    this.onOpenSettings,
    this.onRefreshStatus,
    required this.locationService,
    super.key,
  });

  /// OS 지오펜스에 등록된 장소가 있는가
  final bool isMonitoring;

  /// [isMonitoring] 을 실제로 확인했는가 (이슈 #142 QA).
  ///
  /// 확인 전의 false 를 "꺼짐"으로 그리면 멀쩡한데 고장으로 보인다
  final bool isStatusKnown;

  /// 지금 이어폰이 연결되어 있는가 (줄·USB-C·블루투스)
  final bool isHeadphoneConnected;

  final VoidCallback onAddPlace;
  final void Function(AlertPlace place)? onEditPlace;

  /// 백그라운드 알림이 놓치기 어려운 형태로 오는가 (이슈 #74).
  ///
  /// 기본값이 true 인 이유는, 모르는 상태에서 경고를 띄우면 정상인
  /// 사용자에게 없는 문제를 보여주기 때문이다.
  final bool canAlertReliably;

  /// 아직 켜지지 않은 신뢰성 권한 이름 (이슈 #115)
  final List<String> missingReliability;

  /// 감시가 꺼져 있을 때 해결 경로로 보낸다 — 권한 화면
  final VoidCallback? onFixMonitoring;

  /// 알림이 약할 때 신뢰성 권한을 다시 권하는 경로 (이슈 #74).
  ///
  /// 온보딩에서 "나중에 하기"를 누른 사용자에게 **유일한 재진입 경로**다.
  final VoidCallback? onFixReliability;

  /// 현재 위치 조회 (이슈 #98) — "내 위치" 버튼이 쓴다.
  /// 테스트에서 갈아끼울 수 있게 주입받는다.
  final CurrentLocationService locationService;

  /// 설정 화면을 연다 (이슈 #98).
  ///
  /// 알림음 크기·진단 기록·알림 미리보기가 전부 여기로 들어갔다.
  /// 상태 바에 아이콘이 셋 늘어서면서 정작 중요한 감시 상태가 묻혔기
  /// 때문이다 — 상태 바는 "지금 감시 중인가"를 보여주는 곳이다.
  final VoidCallback? onOpenSettings;

  /// 앱이 다시 앞으로 왔을 때 상태를 다시 읽는다.
  ///
  /// 사용자가 설정에서 권한을 켜거나 이어폰을 꽂고 돌아오는 흐름이
  /// 실제로 가장 흔하다. 그때 화면이 옛 상태를 들고 있으면 안 된다.
  final VoidCallback? onRefreshStatus;

  @override
  ConsumerState<PlaceMapHomeScreen> createState() => _PlaceMapHomeScreenState();
}

class _PlaceMapHomeScreenState extends ConsumerState<PlaceMapHomeScreen>
    with WidgetsBindingObserver {
  /// 등록된 장소가 하나도 없을 때의 초기 지도 위치.
  ///
  /// 현재 위치로 시작하는 것이 이상적이지만 권한이 아직 없을 수 있고
  /// 첫 측정까지 시간이 걸린다. 회색 화면을 보여주느니 기기 지역에 맞는
  /// 곳에서 시작하고 "내 위치" 버튼으로 이동하게 둔다 (이슈 #166).
  final DefaultMapView _fallback = currentDefaultMapView();

  static const _sheetMin = 0.14;
  // 0.3 에서 올렸다 (이슈 #191). 하단 배너가 시트가 쓸 높이를 줄여서, 빈 목록의
  // "장소 등록" 버튼 아래쪽이 잘렸다
  static const _sheetInitial = 0.34;

  GoogleMapController? _map;
  final _sheet = DraggableScrollableController();

  /// 시트가 차지한 화면 비율. FAB 이 시트에 가리지 않게 따라 올라간다
  double _sheetExtent = _sheetInitial;

  /// 지도에서 지목된 장소. 시트에서 테두리로 강조된다
  String? _selectedPlaceId;

  /// 카메라 맞추기는 처음 한 번만. 이후에는 사용자의 조작을 존중한다
  bool _didFitCamera = false;

  /// 현재 위치로 시작하는 조회는 화면이 살아 있는 동안 한 번만 (이슈 #218)
  bool _didTryStartAtCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheet.dispose();
    _map?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onRefreshStatus?.call();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final placesAsync = ref.watch(placeListProvider);
    final places = placesAsync.valueOrNull ?? const <AlertPlace>[];

    if (places.isNotEmpty && !_didFitCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(places));
    }

    // 앱바가 없는 화면 — 상태바 아이콘색을 직접 맞춘다 (이슈 #272)
    return StatusBarIconsFollowingTheme(
      child: Scaffold(
        backgroundColor: context.appColors.background,
        body: Stack(
          children: [
            MapRevealCover(
              screen: 'home',
              builder: (attach) => GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: places.isEmpty
                      ? _fallback.target
                      : LatLng(places.first.latitude, places.first.longitude),
                  zoom: places.isEmpty ? _fallback.zoom : 14,
                ),
                style: MapStyle.jsonForBrightness(Theme.of(context).brightness),
                markers: _markers(places),
                circles: _circles(places, semantic),
                onMapCreated: (controller) {
                  _map = controller;
                  // 다크 스타일이 조용히 사라지는 일이 있다 (이슈 #143)
                  unawaited(
                    ensureMapStyle(
                      controller,
                      'home',
                      style: MapStyle.jsonForBrightness(
                        Theme.of(context).brightness,
                      ),
                    ),
                  );
                  // 다크 타일이 그려질 때까지 밝은 바탕을 가린다 (이슈 #143)
                  attach(controller);
                  if (places.isNotEmpty) _fitCamera(places);
                  // 장소가 없으면 기기 지역 기본 위치가 아니라 내 위치에서 시작한다 (이슈 #218)
                  if (places.isEmpty) unawaited(_startAtCurrentLocation());
                },
                // 빈 곳을 누르면 선택을 푼다 — 강조가 계속 남아 있으면
                // 무엇을 보고 있는지 헷갈린다
                onTap: (_) => _select(null),
                myLocationEnabled: true,
                // **SDK 기본 버튼을 끈다** (이슈 #98). 그 버튼은 우상단 고정이라
                // 상태 알약이 위를 덮어 잘려 보였고, 사용자가 존재 자체를 몰랐다.
                // 커스텀 버튼으로 대체한다 — 장소 추가 위, 오른쪽 스택 (#155).
                //
                // 예전에는 "직접 만들면 현재 위치를 알아낼 방법이 없다"는 이유로
                // SDK 버튼을 썼는데, 이슈 #93 에서 play-services-location 을
                // 넣으면서 그 제약이 사라졌다.
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                // 시트가 지도 하단을 덮는다. padding 을 주면 구글 로고와
                // 내 위치 버튼이 시트 위로 올라온다.
                //
                // 시트 높이를 실시간으로 따라가게 하면 드래그할 때마다 지도가
                // 다시 배치돼 버벅인다. 접힌 높이 기준으로 고정한다.
                padding: EdgeInsets.only(
                  bottom: MediaQuery.sizeOf(context).height * _sheetMin,
                ),
              ),
            ),

            _StatusBar(
              isMonitoring: widget.isMonitoring,
              isStatusKnown: widget.isStatusKnown,
              // 켜진 장소가 없어서 감시가 안 도는 것은 고장이 아니다 —
              // 경고 대신 안내로 보여야 한다
              hasEnabledPlaces: places.any((place) => place.enabled),
              isHeadphoneConnected: widget.isHeadphoneConnected,
              canAlertReliably: widget.canAlertReliably,
              missingReliability: widget.missingReliability,
              onFixMonitoring: widget.onFixMonitoring,
              onFixReliability: widget.onFixReliability,
              onOpenSettings: widget.onOpenSettings,
            ),

            _MapControls(
              bottomFraction: _sheetExtent,
              onMyLocation: _moveToCurrentLocation,
              onAddPlace: widget.onAddPlace,
            ),

            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // 시트가 움직이는 동안 FAB 이 따라 올라간다
                if (notification.extent != _sheetExtent) {
                  setState(() => _sheetExtent = notification.extent);
                }
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _sheetInitial,
                minChildSize: _sheetMin,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [_sheetInitial],
                builder: (context, scrollController) => _PlaceSheet(
                  scrollController: scrollController,
                  places: places,
                  loading: placesAsync.isLoading,
                  failed: placesAsync.hasError,
                  selectedPlaceId: _selectedPlaceId,
                  onAddPlace: widget.onAddPlace,
                  onEditPlace: widget.onEditPlace,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 장소가 없을 때 지도를 내 위치에서 시작한다 (이슈 #218).
  ///
  /// 기본 위치(한국은 서울시청)는 위치를 모를 때의 자리표시일 뿐이다. 권한이 있으면
  /// 사용자가 "내 위치" 버튼을 찾아 누르기 전에 지도가 내 주변을 보여줘야 한다.
  /// 실패해도 안내하지 않는다 — 사용자가 요청한 동작이 아니다. 사유는 채널이 남긴다.
  Future<void> _startAtCurrentLocation() async {
    if (_didTryStartAtCurrentLocation) return;
    _didTryStartAtCurrentLocation = true;

    final location = (await widget.locationService.current()).location;
    if (!mounted || location == null) return;

    // 조회하는 사이 장소가 불러와졌거나 사용자가 이미 지도를 맞췄으면 그쪽이 우선이다
    final hasPlaces =
        (ref.read(placeListProvider).valueOrNull ?? const <AlertPlace>[])
            .isNotEmpty;
    if (!shouldStartAtCurrentLocation(
      hasPlaces: hasPlaces,
      didFitCamera: _didFitCamera,
    )) {
      return;
    }

    Diagnostics.log('location', 'home started at current location');
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        15,
      ),
    );
  }

  /// 현재 위치로 지도를 옮긴다 (이슈 #98).
  ///
  /// 실패하면 **이유를 알려준다.** 아무 일도 일어나지 않으면 사용자는
  /// 버튼이 고장 났다고 생각하고 계속 누른다.
  Future<void> _moveToCurrentLocation() async {
    // 이미 그 위치라 지도가 움직이지 않아도 눌렸다는 걸 알려준다 (이슈 #218)
    unawaited(HapticFeedback.selectionClick());
    final location = await fetchCurrentLocationOrShowReason(
      context,
      widget.locationService,
      screenName: 'home',
    );
    if (location == null) return;

    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        16,
      ),
    );
  }

  Set<Marker> _markers(List<AlertPlace> places) {
    return {
      for (final place in places)
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.latitude, place.longitude),
          // 비활성 장소는 흐리게 — 지도에서 지워버리면 "왜 안 보이지"가 된다
          alpha: place.enabled ? 1 : 0.45,
          icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(place)),
          // **정보 말풍선을 띄우지 않는다** (이슈 #228). SDK 말풍선은 흰 바탕
          // 고정이라 다크 지도 위에서 혼자 튀었다. 마커를 누르면 시트의 카드가
          // 강조되고 원이 굵어져 같은 정보(이름·방향·반경)를 이미 보여준다
          onTap: () => _onMarkerTapped(place),
        ),
    };
  }

  Set<Circle> _circles(List<AlertPlace> places, AppSemanticColors semantic) {
    return {
      for (final place in places)
        Circle(
          circleId: CircleId(place.id),
          center: LatLng(place.latitude, place.longitude),
          radius: place.radiusMeters.toDouble(),
          strokeWidth: _selectedPlaceId == place.id ? 3 : 2,
          strokeColor: _directionColor(
            place,
            semantic,
          ).withValues(alpha: place.enabled ? 1 : 0.4),
          fillColor: _directionColor(
            place,
            semantic,
          ).withValues(alpha: place.enabled ? 0.12 : 0.05),
        ),
    };
  }

  /// 카드와 같은 색 규칙을 쓴다 (place_card.dart `describeDirection`)
  Color _directionColor(AlertPlace place, AppSemanticColors semantic) =>
      place.direction.colorFrom(semantic);

  double _markerHue(AlertPlace place) => markerHueFor(place.direction);

  /// 마커를 누르면 그 장소를 지목하고 시트를 연다.
  ///
  /// 편집으로 바로 보내지 않는 이유는, 마커를 누르는 동작이 대개
  /// "이게 뭐지"를 확인하려는 것이지 고치려는 게 아니기 때문이다.
  void _onMarkerTapped(AlertPlace place) {
    _select(place.id);
    _map?.animateCamera(
      CameraUpdate.newLatLng(LatLng(place.latitude, place.longitude)),
    );
    if (_sheet.isAttached && _sheet.size < _sheetInitial) {
      _sheet.animateTo(
        _sheetInitial,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _select(String? placeId) {
    if (_selectedPlaceId == placeId) return;
    setState(() => _selectedPlaceId = placeId);
  }

  /// 등록된 장소가 모두 한 화면에 들어오게 맞춘다.
  ///
  /// 첫 장소가 화면 밖에 있으면 "등록이 안 됐나" 싶어진다.
  Future<void> _fitCamera(List<AlertPlace> places) async {
    final map = _map;
    if (map == null || places.isEmpty || _didFitCamera) return;
    _didFitCamera = true;

    if (places.length == 1) {
      final place = places.first;
      await map.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.latitude, place.longitude),
          // 홈은 "어디쯤인지"를 보여주는 화면이라 한 단계 넓게 잡는다
          zoomForRadiusWider(place.radiusMeters.toDouble()),
        ),
      );
      return;
    }

    var minLat = places.first.latitude;
    var maxLat = places.first.latitude;
    var minLng = places.first.longitude;
    var maxLng = places.first.longitude;
    for (final place in places) {
      minLat = math.min(minLat, place.latitude);
      maxLat = math.max(maxLat, place.latitude);
      minLng = math.min(minLng, place.longitude);
      maxLng = math.max(maxLng, place.longitude);
    }

    try {
      await map.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          AppSpacing.lg,
        ),
      );
    } on Object catch (error) {
      // 지도 크기가 아직 확정되지 않으면 실패한다. 기본 위치로 둔다
      Diagnostics.log('map', 'fit places camera failed error=$error');
    }
  }
}
