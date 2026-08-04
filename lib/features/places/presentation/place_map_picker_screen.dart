import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/map_style.dart';
import '../domain/place_search.dart';
import '../domain/place_validator.dart';

/// 지도에서 고른 결과 — 위치와 반경을 함께 돌려준다.
///
/// 반경 슬라이더를 지도 위에 둔 이유는 "100m 가 어느 정도인지" 숫자로
/// 아는 사람이 없기 때문이다 (docs/06-UX.md). 원을 보면서 정해야 한다.
class MapPickResult {
  const MapPickResult({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final double latitude;
  final double longitude;
  final int radiusMeters;
}

/// 지도 화면에 넘기는 초기값
class MapPickArgs {
  const MapPickArgs({
    this.latitude,
    this.longitude,
    required this.radiusMeters,
  });

  /// null 이면 기본 위치에서 시작한다 (신규 등록)
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
}

/// 지도에서 위치 선택 (docs/06-UX.md "위치 추가 / 편집")
///
/// **중앙 고정 핀 방식이다.** 핀을 끌어다 놓는 대신 지도를 움직여 맞춘다 —
/// 버스에서 한 손으로 조작할 때 이쪽이 정확하고 쉽다. 핀이 손가락에
/// 가리지도 않는다.
class PlaceMapPickerScreen extends StatefulWidget {
  const PlaceMapPickerScreen({
    required this.args,
    this.onPicked,
    this.searchService,
    super.key,
  });

  final MapPickArgs args;

  /// 선택 완료. 라우터가 화면을 닫으며 결과를 돌려준다
  final ValueChanged<MapPickResult>? onPicked;

  /// 장소 검색 (F1.2, issue #72). null 이면 검색창을 그리지 않는다 —
  /// 지도·핀·저장은 검색 없이도 전부 동작해야 한다
  final PlaceSearchService? searchService;

  /// 지도 초기 위치 — 좌표가 없을 때 쓴다.
  ///
  /// 사용자의 현재 위치로 시작하는 것이 이상적이지만, 위치 권한이 아직
  /// 없을 수 있고 첫 측정까지 시간이 걸린다. 회색 화면을 보여주느니
  /// 고정 좌표에서 시작하고 "내 위치" 버튼으로 이동하게 둔다.
  static const _fallback = LatLng(37.5665, 126.9780); // 서울시청

  @override
  State<PlaceMapPickerScreen> createState() => _PlaceMapPickerScreenState();
}

class _PlaceMapPickerScreenState extends State<PlaceMapPickerScreen> {
  late LatLng _center = _initialCenter;
  late double _radius = widget.args.radiusMeters.toDouble();

  GoogleMapController? _map;

  // ── 검색 상태 ──
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  /// 마지막으로 보낸 질의. 늦게 도착한 옛 응답이 새 결과를 덮지 못하게 한다
  String _inFlightQuery = '';
  List<PlaceSearchResult> _results = const [];
  bool _searching = false;
  bool _searchUnavailable = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  LatLng get _initialCenter {
    final latitude = widget.args.latitude;
    final longitude = widget.args.longitude;
    if (latitude == null || longitude == null) {
      return PlaceMapPickerScreen._fallback;
    }
    return LatLng(latitude, longitude);
  }

  // ── 검색 ────────────────────────────────────────────────────

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    // 타자마다 요청하지 않는다 — 과금 요청 수가 그대로 늘어난다
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final service = widget.searchService;
    if (service == null) return;

    setState(() {
      _searching = true;
      _searchUnavailable = false;
    });
    _inFlightQuery = query;

    try {
      final results = await service.search(query);
      if (!mounted || _inFlightQuery != query) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on PlaceSearchUnavailable {
      if (!mounted || _inFlightQuery != query) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchUnavailable = true;
      });
    }
  }

  /// 결과를 고르면 **카메라만 옮긴다.** 좌표 확정은 여전히 핀이다 —
  /// 검색 좌표가 출입구 반대편일 수 있고, 최종 판단은 사용자의 눈이다.
  void _onResultTapped(PlaceSearchResult result) {
    _searchFocus.unfocus();
    setState(() => _results = const []);
    _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(result.latitude, result.longitude),
        _zoomForRadius(_radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(title: const Text('지도에서 선택')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _map = controller,
            initialCameraPosition: CameraPosition(
              target: _initialCenter,
              zoom: _zoomForRadius(_radius),
            ),
            style: MapStyle.dark,
            // 원의 중심이 카메라 중심이라, 화면에서는 핀 자리에 고정되어
            // 보이고 반경만 커졌다 작아진다
            circles: {
              Circle(
                circleId: const CircleId('picking'),
                center: _center,
                radius: _radius,
                strokeWidth: 2,
                strokeColor: semantic.alertEnter,
                fillColor: semantic.alertEnter.withValues(alpha: 0.12),
              ),
            },
            onCameraMove: (position) =>
                setState(() => _center = position.target),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            // 기본 확대 버튼은 다크 테마에 맞지 않고, 핀치로 충분하다
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 중앙 고정 핀. 지도 조작을 가로막지 않아야 한다
          IgnorePointer(
            child: Center(
              child: Padding(
                // 핀 끝이 정중앙을 가리키도록 아이콘 높이의 절반만큼 올린다
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.place_outlined,
                  size: 40,
                  color: semantic.alertEnter,
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: _PickerPanel(
              radius: _radius,
              onRadiusChanged: (value) => setState(() => _radius = value),
              onConfirm: () => widget.onPicked?.call(
                MapPickResult(
                  latitude: _center.latitude,
                  longitude: _center.longitude,
                  radiusMeters: _radius.round(),
                ),
              ),
            ),
          ),

          // 검색은 지도 위에 얹는다 — 핀·반경 조작을 가리지 않게 상단에만
          if (widget.searchService != null)
            _SearchOverlay(
              controller: _searchController,
              focusNode: _searchFocus,
              results: _results,
              searching: _searching,
              unavailable: _searchUnavailable,
              onChanged: _onQueryChanged,
              onResultTapped: _onResultTapped,
            ),
        ],
      ),
    );
  }

  /// 반경이 화면에 적당히 차 보이는 확대 수준.
  ///
  /// 반경 50m 를 세계 지도에서 찍게 하면 아무도 못 찍는다.
  double _zoomForRadius(double meters) {
    if (meters <= 100) return 17;
    if (meters <= 300) return 16;
    if (meters <= 800) return 15;
    return 14;
  }
}

/// 검색창 + 결과 목록 오버레이
class _SearchOverlay extends StatelessWidget {
  const _SearchOverlay({
    required this.controller,
    required this.focusNode,
    required this.results,
    required this.searching,
    required this.unavailable,
    required this.onChanged,
    required this.onResultTapped,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<PlaceSearchResult> results;
  final bool searching;
  final bool unavailable;
  final ValueChanged<String> onChanged;
  final ValueChanged<PlaceSearchResult> onResultTapped;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: AppTypography.body,
                decoration: InputDecoration(
                  hintText: '장소·주소 검색',
                  hintStyle: AppTypography.caption,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  prefixIcon: const Icon(Icons.search_outlined, size: 20),
                  suffixIcon: searching
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_outlined, size: 18),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        ),
                ),
              ),
            ),

            if (unavailable)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: _SearchMessage('검색을 사용할 수 없습니다 — 지도를 움직여 위치를 맞춰주세요'),
              )
            else if (results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.bgElevated),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 20),
                      title: Text(
                        result.name,
                        style: AppTypography.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: result.address.isEmpty
                          ? null
                          : Text(
                              result.address,
                              style: AppTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => onResultTapped(result),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(message, style: AppTypography.caption),
    );
  }
}

class _PickerPanel extends StatelessWidget {
  const _PickerPanel({
    required this.radius,
    required this.onRadiusChanged,
    required this.onConfirm,
  });

  final double radius;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '알림 반경 ${radius.round()}m',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: radius,
              min: PlaceValidator.minRadiusMeters.toDouble(),
              max: PlaceValidator.maxRadiusMeters.toDouble(),
              divisions: 39,
              onChanged: onRadiusChanged,
            ),
            Text(
              '지도를 움직여 핀을 맞추세요',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('이 위치로 선택'),
            ),
          ],
        ),
      ),
    );
  }
}
