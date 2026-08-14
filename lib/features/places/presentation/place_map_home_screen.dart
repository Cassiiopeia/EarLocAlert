import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/map_style.dart';
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
    this.canAlertReliably = true,
    this.onEditPlace,
    this.onFixMonitoring,
    this.onFixReliability,
    this.onPreviewAlert,
    this.onOpenVolumeSettings,
    this.onOpenDiagnostics,
    this.onRefreshStatus,
    super.key,
  });

  /// OS 지오펜스에 등록된 장소가 있는가
  final bool isMonitoring;

  /// 지금 이어폰이 연결되어 있는가 (줄·USB-C·블루투스)
  final bool isHeadphoneConnected;

  final VoidCallback onAddPlace;
  final void Function(AlertPlace place)? onEditPlace;

  /// 백그라운드 알림이 놓치기 어려운 형태로 오는가 (이슈 #74).
  ///
  /// 기본값이 true 인 이유는, 모르는 상태에서 경고를 띄우면 정상인
  /// 사용자에게 없는 문제를 보여주기 때문이다.
  final bool canAlertReliably;

  /// 감시가 꺼져 있을 때 해결 경로로 보낸다 — 권한 화면
  final VoidCallback? onFixMonitoring;

  /// 알림이 약할 때 신뢰성 권한을 다시 권하는 경로 (이슈 #74).
  ///
  /// 온보딩에서 "나중에 하기"를 누른 사용자에게 **유일한 재진입 경로**다.
  final VoidCallback? onFixReliability;

  /// 알림 흐름 수동 확인 (실기기 스파이크 S-4·S-5 용).
  /// 지오펜스 실기기 검증이 끝나면 제거한다 (docs/11-ROADMAP.md).
  final VoidCallback? onPreviewAlert;

  /// 알림음 크기 설정을 연다 (이슈 #86).
  /// 알림 설정은 alert feature 소관이라 app 계층이 콜백으로 잇는다 (규칙 1).
  final VoidCallback? onOpenVolumeSettings;

  /// 진단 기록을 연다 (이슈 #95).
  ///
  /// **"도착했는데 안 울렸다"를 확인할 수 있는 유일한 창구다.**
  /// 이 앱은 백그라운드 동작이 핵심이라 재현이 어렵고, 로그가 없으면
  /// 사용자도 개발자도 아무것도 볼 수 없다.
  final VoidCallback? onOpenDiagnostics;

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
          GoogleMap(
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
              if (places.isNotEmpty) _fitCamera(places);
            },
            // 빈 곳을 누르면 선택을 푼다 — 강조가 계속 남아 있으면
            // 무엇을 보고 있는지 헷갈린다
            onTap: (_) => _select(null),
            myLocationEnabled: true,
            // 지도 SDK 의 버튼을 쓴다. 직접 만들면 현재 위치를 알아낼 방법이
            // 없어 "내 위치"라고 써놓고 확대만 하는 버튼이 된다
            myLocationButtonEnabled: true,
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

          _StatusBar(
            isMonitoring: widget.isMonitoring,
            // 켜진 장소가 없어서 감시가 안 도는 것은 고장이 아니다 —
            // 경고 대신 안내로 보여야 한다
            hasEnabledPlaces: places.any((place) => place.enabled),
            isHeadphoneConnected: widget.isHeadphoneConnected,
            canAlertReliably: widget.canAlertReliably,
            onFixMonitoring: widget.onFixMonitoring,
            onFixReliability: widget.onFixReliability,
            onPreviewAlert: widget.onPreviewAlert,
            onOpenVolumeSettings: widget.onOpenVolumeSettings,
            onOpenDiagnostics: widget.onOpenDiagnostics,
          ),

          _AddPlaceButton(
            bottomFraction: _sheetExtent,
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
          _zoomForRadius(place.radiusMeters),
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

  double _zoomForRadius(int meters) {
    if (meters <= 100) return 16;
    if (meters <= 300) return 15;
    if (meters <= 800) return 14;
    return 13;
  }
}

/// 상단 상태 바 — 이 화면의 존재 이유 (F4.5)
///
/// 감시가 꺼져 있으면 **눈에 띄어야 하고 해결 경로가 있어야 한다.**
/// "안 울린다"는 문제의 대부분이 여기서 미리 잡힌다.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.isMonitoring,
    required this.hasEnabledPlaces,
    required this.isHeadphoneConnected,
    required this.canAlertReliably,
    this.onFixMonitoring,
    this.onFixReliability,
    this.onPreviewAlert,
    this.onOpenVolumeSettings,
    this.onOpenDiagnostics,
  });

  final bool isMonitoring;

  /// 켜진 장소가 하나라도 있는가.
  ///
  /// 감시가 안 도는 이유를 가른다 — 켜진 장소가 없으면 **정상 대기**이고,
  /// 있는데도 안 돌면 **고장(권한 등)**이다. 첫 사용자에게 경고를
  /// 들이밀면 안 된다.
  final bool hasEnabledPlaces;

  final bool isHeadphoneConnected;

  /// 백그라운드 알림이 놓치기 어려운 형태로 오는가 (이슈 #74)
  final bool canAlertReliably;

  final VoidCallback? onFixMonitoring;
  final VoidCallback? onFixReliability;
  final VoidCallback? onPreviewAlert;

  /// 알림음 크기 설정 (이슈 #86)
  final VoidCallback? onOpenVolumeSettings;

  /// 진단 기록 (이슈 #95) — "안 울렸다"를 확인하는 창구
  final VoidCallback? onOpenDiagnostics;

  /// 고장 상태 — 켜진 장소가 있는데 감시가 안 돈다. 해결 경로가 필요하다
  bool get _isBroken => hasEnabledPlaces && !isMonitoring;

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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusPill(semantic, statusColor),
            if (_isWeak) ...[
              const SizedBox(height: AppSpacing.xs),
              _WeakAlertBanner(onTap: onFixReliability!),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              // 색만으로 구분하지 않는다 — 아이콘과 문구를 함께 쓴다
              Icon(
                isMonitoring
                    ? Icons.radar_outlined
                    : _isBroken
                    ? Icons.warning_amber_outlined
                    : Icons.pause_circle_outlined,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  isMonitoring
                      ? '감시 중'
                      : _isBroken
                      ? '감시 꺼짐 · 눌러서 확인'
                      : '감시 대기 · 장소를 켜면 시작됩니다',
                  style: AppTypography.caption.copyWith(color: statusColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 1,
                height: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                isHeadphoneConnected
                    ? Icons.headphones_outlined
                    : Icons.vibration_outlined,
                size: 18,
                color: isHeadphoneConnected
                    ? semantic.audioBluetooth
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                isHeadphoneConnected ? '이어폰' : '진동만',
                style: AppTypography.caption,
              ),
              if (onPreviewAlert != null || onOpenVolumeSettings != null)
                const Spacer(),
              // 이어폰 상태 바로 옆이 볼륨 설정의 제자리다 (이슈 #86) —
              // "이어폰으로 얼마나 크게"가 한 시야에 들어온다
              if (onOpenVolumeSettings != null)
                IconButton(
                  onPressed: onOpenVolumeSettings,
                  icon: const Icon(Icons.tune_outlined),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: '알림음 크기',
                ),
              if (onPreviewAlert != null)
                IconButton(
                  onPressed: onPreviewAlert,
                  icon: const Icon(Icons.notifications_active_outlined),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: '알림 미리보기',
                ),
              // "안 울렸다"를 확인하는 창구 (이슈 #95).
              // 감시 상태 바로 옆이 제자리다 — 알림이 안 왔을 때 사용자가
              // 가장 먼저 보는 곳이고, 그 다음 질문이 "왜?"이기 때문이다.
              if (onOpenDiagnostics != null)
                IconButton(
                  onPressed: onOpenDiagnostics,
                  icon: const Icon(Icons.receipt_long_outlined),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: '진단 기록',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 알림이 약할 때만 뜨는 안내 (이슈 #74)
///
/// **경고가 아니라 안내다.** 알림은 오고 있고, 이걸 켜면 더 확실해진다는
/// 뜻이다. 온보딩에서 건너뛴 사용자에게 유일한 재진입 경로이기도 하다.
class _WeakAlertBanner extends StatelessWidget {
  const _WeakAlertBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_paused_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  '절전·다른 앱 사용 중에는 알림이 약합니다 · 눌러서 강화',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
class _AddPlaceButton extends StatelessWidget {
  const _AddPlaceButton({
    required this.bottomFraction,
    required this.onAddPlace,
  });

  final double bottomFraction;
  final VoidCallback onAddPlace;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: AppSpacing.sm,
      bottom:
          MediaQuery.sizeOf(context).height * bottomFraction + AppSpacing.sm,
      child: FloatingActionButton(
        onPressed: onAddPlace,
        child: const Icon(Icons.add_outlined),
      ),
    );
  }
}

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
