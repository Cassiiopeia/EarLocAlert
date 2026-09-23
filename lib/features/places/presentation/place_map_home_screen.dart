import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/map/map_reveal_cover.dart';
import '../../../core/map/map_style_guard.dart';
import '../../../core/map/radius_zoom.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/widgets/floating_circle_button.dart';
import '../data/current_location_channel.dart';
import '../domain/alert_place.dart';
import 'place_card.dart';
import 'place_empty_state.dart';
import 'place_list_controller.dart';

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
    this.locationService = const CurrentLocationChannel(),
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
  /// 첫 측정까지 시간이 걸린다. 회색 화면을 보여주느니 고정 좌표에서
  /// 시작하고 "내 위치" 버튼으로 이동하게 둔다.
  static const _fallback = LatLng(37.5665, 126.9780); // 서울시청

  static const _sheetMin = 0.14;
  static const _sheetInitial = 0.3;

  GoogleMapController? _map;
  final _sheet = DraggableScrollableController();

  /// 시트가 차지한 화면 비율. FAB 이 시트에 가리지 않게 따라 올라간다
  double _sheetExtent = _sheetInitial;

  /// 지도에서 지목된 장소. 시트에서 테두리로 강조된다
  String? _selectedPlaceId;

  /// 카메라 맞추기는 처음 한 번만. 이후에는 사용자의 조작을 존중한다
  bool _didFitCamera = false;

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

    // 장소가 처음 도착한 시점에 카메라를 맞춘다
    if (places.isNotEmpty && !_didFitCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(places));
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          MapRevealCover(
            screen: 'home',
            builder: (attach) => GoogleMap(
              initialCameraPosition: CameraPosition(
                target: places.isEmpty
                    ? _fallback
                    : LatLng(places.first.latitude, places.first.longitude),
                zoom: 14,
              ),
              style: MapStyle.dark,
              markers: _markers(places, semantic),
              circles: _circles(places, semantic),
              onMapCreated: (controller) {
                _map = controller;
                // 다크 스타일이 조용히 사라지는 일이 있다 (이슈 #143)
                unawaited(ensureDarkMapStyle(controller, 'home'));
                // 다크 타일이 그려질 때까지 밝은 바탕을 가린다 (이슈 #143)
                attach(controller);
                if (places.isNotEmpty) _fitCamera(places);
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
    );
  }

  /// 현재 위치로 지도를 옮긴다 (이슈 #98).
  ///
  /// 실패하면 **이유를 알려준다.** 아무 일도 일어나지 않으면 사용자는
  /// 버튼이 고장 났다고 생각하고 계속 누른다.
  Future<void> _moveToCurrentLocation() async {
    final location = await widget.locationService.current();
    if (!mounted) return;

    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('현재 위치를 확인할 수 없습니다. 위치 권한을 확인해주세요'.keepAll)),
      );
      return;
    }

    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        16,
      ),
    );
  }

  // ── 지도 요소 ────────────────────────────────────────────────

  Set<Marker> _markers(List<AlertPlace> places, AppSemanticColors semantic) {
    return {
      for (final place in places)
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.latitude, place.longitude),
          // 비활성 장소는 흐리게 — 지도에서 지워버리면 "왜 안 보이지"가 된다
          alpha: place.enabled ? 1 : 0.45,
          icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(place)),
          infoWindow: InfoWindow(
            title: place.name,
            // 카드와 같은 문구를 쓴다 — 지도와 목록이 다른 말을 하면 안 된다
            snippet:
                '${describeDirection(place.direction, semantic).$2} · 반경 ${place.radiusMeters}m',
          ),
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
      place.direction == AlertDirection.exit
      ? semantic.alertExit
      : semantic.alertEnter;

  /// 기본 마커는 색을 자유롭게 줄 수 없고 hue 만 지정된다.
  /// 팔레트의 두 주색에 가장 가까운 값을 쓴다 — 커스텀 아이콘을 그리는
  /// 것보다 유지비가 싸고, 방향 구분은 마커 옆 원 색이 함께 해준다.
  double _markerHue(AlertPlace place) => place.direction == AlertDirection.exit
      ? BitmapDescriptor.hueOrange
      : BitmapDescriptor.hueCyan;

  // ── 상호작용 ────────────────────────────────────────────────

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
    } on Object {
      // 지도 크기가 아직 확정되지 않으면 실패한다. 기본 위치로 둔다
    }
  }
}

/// 상단 상태 바 — 이 화면의 존재 이유 (F4.5)
///
/// 감시가 꺼져 있으면 **눈에 띄어야 하고 해결 경로가 있어야 한다.**
/// "안 울린다"는 문제의 대부분이 여기서 미리 잡힌다.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.isMonitoring,
    required this.isStatusKnown,
    required this.hasEnabledPlaces,
    required this.isHeadphoneConnected,
    required this.canAlertReliably,
    this.missingReliability = const [],
    this.onFixMonitoring,
    this.onFixReliability,
    this.onOpenSettings,
  });

  final bool isMonitoring;

  /// 감시 상태를 실제로 확인했는가 — false 면 "확인 중"
  final bool isStatusKnown;

  /// 켜진 장소가 하나라도 있는가.
  ///
  /// 감시가 안 도는 이유를 가른다 — 켜진 장소가 없으면 **정상 대기**이고,
  /// 있는데도 안 돌면 **고장(권한 등)**이다. 첫 사용자에게 경고를
  /// 들이밀면 안 된다.
  final bool hasEnabledPlaces;

  final bool isHeadphoneConnected;

  /// 백그라운드 알림이 놓치기 어려운 형태로 오는가 (이슈 #74)
  final bool canAlertReliably;

  /// 아직 켜지지 않은 신뢰성 권한 이름 (이슈 #115)
  final List<String> missingReliability;

  final VoidCallback? onFixMonitoring;
  final VoidCallback? onFixReliability;

  /// 설정 화면 (이슈 #98) — 알림음 크기·진단 기록이 여기 있다
  final VoidCallback? onOpenSettings;

  /// 고장 상태 — 켜진 장소가 있는데 감시가 안 돈다. 해결 경로가 필요하다.
  ///
  /// **확인하기 전에는 고장이 아니다** (이슈 #142 QA) — 모르는 것을
  /// 고장으로 그리면 알림을 끄고 돌아올 때마다 오경보가 뜬다
  bool get _isBroken => isStatusKnown && hasEnabledPlaces && !isMonitoring;

  /// 켜진 장소는 있는데 감시 상태를 아직 읽는 중이다
  bool get _isChecking => !isStatusKnown && hasEnabledPlaces;

  /// 감시는 도는데 알림이 약하다 (이슈 #74).
  ///
  /// **고장과 구분한다.** 알림은 오고 있으므로 경고색을 쓰지 않고,
  /// 감시가 아예 안 도는 상황에서는 그쪽이 먼저라 띄우지 않는다.
  bool get _isWeak =>
      !_isBroken && !canAlertReliably && onFixReliability != null;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final statusColor = isMonitoring
        ? semantic.statusActive
        : _isBroken
        ? semantic.statusInactive
        : AppColors.textSecondary; // 정상 대기 — 경고색을 쓰지 않는다

    // 설정 버튼은 보이는 원보다 탭 영역이 크다. 그 차이만큼 바깥 여백에서
    // 빼야 **보이는 원이 예전 자리 그대로** 오른쪽 끝·알약과 같은 높이에
    // 선다 — 안 빼면 #155 에서 맞춘 좌우 여백이 다시 어긋난다
    const overhang = _SettingsButton.slop;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm - overhang,
          AppSpacing.sm - overhang,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // **설정을 알약 밖에 둔다** (이슈 #155).
            //
            // 예전에는 알약 안에 `Spacer()` + `IconButton` 으로 넣었는데
            // 셋이 겹쳤다 — Spacer 가 알약을 화면 폭까지 늘려 가운데가
            // 휑했고, IconButton 의 내부 패딩이 알약 패딩 위에 또 붙어
            // 오른쪽 여백이 왼쪽과 맞지 않았다. 무엇보다 알약 자체가
            // "감시 고장 시 권한 화면" 탭 대상인데 그 안에 성격이 다른
            // 버튼이 또 있어, 어느 쪽을 누르는 것인지 모호했다.
            Row(
              // **`Spacer` 를 쓰지 않는다.** flex 공간을 먼저 가져가서 알약이
              // 눌리고, 로고가 들어온 뒤로는 그대로 넘쳤다(실기기에서 22px).
              // `spaceBetween` 은 알약에 필요한 만큼 주고 남은 공간으로
              // 설정을 오른쪽 끝에 민다.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: _statusPill(semantic, statusColor)),
                if (onOpenSettings != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _SettingsButton(onPressed: onOpenSettings!),
                ],
              ],
            ),
            if (_isWeak) ...[
              const SizedBox(height: AppSpacing.xs - overhang),
              Padding(
                // 위에서 뺀 오른쪽 여백을 배너에는 돌려준다
                padding: const EdgeInsets.only(right: overhang),
                child: _WeakAlertBanner(
                  onTap: onFixReliability!,
                  missing: missingReliability,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(AppSemanticColors semantic, Color statusColor) {
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        // 고장일 때만 해결 경로(권한 화면)로 보낸다.
        // 장소가 없어서 대기 중인 사용자를 온보딩에 다시 보내면 안 된다
        onTap: _isBroken ? onFixMonitoring : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // 높이는 설정 버튼·내 위치 버튼과 같은 40 — 지도 위에 떠 있는
        // 조작 요소는 한 높이로 선다 (docs/06-UX.md)
        child: SizedBox(
          height: AppControlSize.floating,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              // 내용만큼만 차지한다 — 늘어나면 가운데가 휑해진다
              mainAxisSize: MainAxisSize.min,
              children: [
                // **로고를 알약 안에 둔다** (이슈 #155).
                //
                // 따로 띄우면 지도 위에 떠 있는 덩어리가 하나 늘고 그만큼
                // 지도가 안 보인다. 구글 지도가 검색창 **안쪽** 왼쪽 끝에
                // G 로고를 넣은 것과 같은 구조다.
                //
                // 앱 아이콘에서 딴 그림을 쓴다 — 따로 그리면 아이콘을 바꿨을
                // 때 또 어긋난다 (스플래시가 두 달 그랬다, #150).
                //
                // **여백 없는 판을 쓴다.** 예전에는 스플래시 판을 폭 16 으로
                // 넣었는데, 그 판은 768 에 핀이 468 뿐이라 핀이 7dp 로
                // 쪼그라들어 옆 아이콘의 절반으로 보였다. 높이를 옆 아이콘과
                // 같은 18 로 맞춘다 (이슈 #155 QA)
                Image.asset(
                  'assets/icon/app_logo_mark.png',
                  height: AppIconSize.standard,
                  filterQuality: FilterQuality.medium,
                ),
                // 로고와 상태를 한 칸 떼어 놓는다 — 붙어 있으면 청록 아이콘 둘이
                // 한 덩어리로 보여 무엇이 로고인지 흐려진다 (디자인 리뷰)
                const SizedBox(width: AppSpacing.sm),
                // 색만으로 구분하지 않는다 — 아이콘과 문구를 함께 쓴다
                Icon(
                  isMonitoring
                      ? Icons.radar_outlined
                      : _isBroken
                      ? Icons.warning_amber_outlined
                      : _isChecking
                      ? Icons.hourglass_empty_outlined
                      : Icons.pause_circle_outlined,
                  size: AppIconSize.control,
                  color: statusColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                // **라벨만 쓴다.** 예전에는 '감시 대기 · 장소를 켜면 시작됩니다'
                // 같은 문장이라 40px ~ 192px 로 4.8배까지 벌어졌고, 알약 안에서
                // 잘려 "장소를 켜면…" 이 되어 아무것도 알려주지 못했다.
                //
                // 설명이 필요한 말은 **빈 화면이 이미 하고 있다**
                // ("첫 장소를 등록해보세요"). 같은 말을 두 곳에서 하지 않는다.
                Flexible(
                  child: Text(
                    isMonitoring
                        ? '감시 중'
                        : _isBroken
                        ? '감시 꺼짐'
                        : _isChecking
                        ? '확인 중'
                        : '감시 대기',
                    style: AppTypography.body.copyWith(color: statusColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 누를 수 있다는 것은 글자보다 모양이 빠르다 — '눌러서 확인'
                // 대신 꺾쇠를 둔다
                if (_isBroken)
                  Icon(
                    Icons.chevron_right_outlined,
                    size: AppIconSize.control,
                    color: statusColor,
                  ),

                // 구분선 둘을 가운뎃점 하나로 — 요소가 일곱에서 여섯으로 준다
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '·',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),

                Icon(
                  isHeadphoneConnected
                      ? Icons.headphones_outlined
                      : Icons.vibration_outlined,
                  size: AppIconSize.control,
                  color: isHeadphoneConnected
                      ? semantic.audioBluetooth
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  isHeadphoneConnected ? '이어폰' : '진동만',
                  style: AppTypography.body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    const accent = AppColors.primary;

    // **불투명해야 한다.** 지도 위에 뜨는 배너라 반투명이면 도로와 지명이
    // 글자 뒤로 비쳐 읽히지 않는다. 표면색에 강조색을 섞어 경고 기운은
    // 남기되 바탕은 가린다
    return Material(
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.22),
        AppColors.bgSurface,
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
              const Icon(Icons.warning_amber_outlined, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '알림을 놓칠 수 있습니다',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // 조사를 붙이지 않는다 — 항목 이름이 바뀔 때마다
                      // 은/는·이/가가 어긋난다
                      (missing.isEmpty
                              ? '절전 중이거나 다른 앱을 쓰는 동안 알림이 약해집니다'
                              : '${missing.join(" · ")} 꺼짐 — 눌러서 켜기')
                          .keepAll,
                      style: AppTypography.caption,
                      // **두 줄까지 보여준다** — 한 줄로 자르면 정작 무엇이
                      // 꺼졌는지가 잘려 나간다
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_outlined, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingCircleButton(
            icon: Icons.my_location_outlined,
            onPressed: onMyLocation,
            semanticLabel: '내 위치',
            slop: const EdgeInsets.fromLTRB(_slop, _slop, _slop, gapHalf),
          ),
          FloatingCircleButton(
            icon: Icons.add_outlined,
            onPressed: onAddPlace,
            semanticLabel: '장소 추가',
            size: AppControlSize.primary,
            background: AppColors.primary,
            foreground: AppColors.textOnPrimary,
            slop: const EdgeInsets.fromLTRB(_slop, gapHalf, _slop, _slop),
          ),
        ],
      ),
    );
  }
}

/// 떠 있는 버튼이 보이는 모양보다 넓게 받는 폭
const double _slop = AppSpacing.xs;

/// 하단 시트 — 등록한 장소 목록
class _PlaceSheet extends ConsumerWidget {
  const _PlaceSheet({
    required this.scrollController,
    required this.places,
    required this.loading,
    required this.failed,
    required this.selectedPlaceId,
    required this.onAddPlace,
    this.onEditPlace,
  });

  final ScrollController scrollController;
  final List<AlertPlace> places;
  final bool loading;
  final bool failed;
  final String? selectedPlaceId;
  final VoidCallback onAddPlace;
  final void Function(AlertPlace place)? onEditPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: Column(
        children: [
          // 손잡이 — 이 시트가 끌어올려진다는 유일한 단서다
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Expanded(child: _body(context, ref)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    if (failed) {
      return ListView(
        controller: scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              '장소를 불러오지 못했습니다',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (loading && places.isEmpty) {
      return ListView(
        controller: scrollController,
        children: const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (places.isEmpty) {
      // 스크롤 가능해야 시트를 끌어내릴 수 있다
      return ListView(
        controller: scrollController,
        children: [PlaceEmptyState(onAddPlace: onAddPlace, compact: true)],
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final place = places[index];
        return PlaceCard(
          place: place,
          selected: place.id == selectedPlaceId,
          onTap: () => onEditPlace?.call(place),
          onToggle: (enabled) => ref
              .read(placeActionsProvider.notifier)
              .setEnabled(place.id, enabled: enabled),
          onDelete: () => deletePlaceWithUndo(context, ref, place),
        );
      },
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  /// 보이는 원 바깥으로 더 받는 폭
  static const double slop = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    // 떠 있는 버튼은 한 규격으로 (디자인 리뷰 #155) — 모양·크기·탭 범위를
    // 공용 버튼이 정한다. 예전 38×34dp 원은 최소 터치 타깃에도 못 미쳤다
    return FloatingCircleButton(
      icon: Icons.settings_outlined,
      onPressed: onPressed,
      semanticLabel: '설정',
    );
  }
}
