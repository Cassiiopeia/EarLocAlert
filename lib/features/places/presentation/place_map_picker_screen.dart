import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/map/map_reveal_cover.dart';
import '../../../core/map/map_style_guard.dart';
import '../../../core/map/radius_zoom.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/widgets/hit_slop.dart';
import '../data/current_location_channel.dart';
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
    this.locationService = const CurrentLocationChannel(),
    super.key,
  });

  final MapPickArgs args;

  /// 선택 완료. 라우터가 화면을 닫으며 결과를 돌려준다
  final ValueChanged<MapPickResult>? onPicked;

  /// 장소 검색 (F1.2, issue #72). null 이면 검색창을 그리지 않는다 —
  /// 지도·핀·저장은 검색 없이도 전부 동작해야 한다
  final PlaceSearchService? searchService;

  /// 현재 위치 조회. 홈 화면과 같은 서비스·같은 기본값을 쓴다 (이슈 #152).
  ///
  /// 테스트는 `UnavailableCurrentLocationService` 로 바꿔 끼운다.
  final CurrentLocationService locationService;

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
  static const double _pinSize = 40;

  /// `Icons.place_outlined` 의 끝이 아이콘 상자 바닥에서 떨어진 비율 (2/24)
  static const double _pinTipInset = 2 / 24;

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
        _fitZoom(LatLng(result.latitude, result.longitude)),
      ),
    );
  }

  /// 원 지름이 화면 폭의 70% 가 되는 줌 (이슈 #152 QA)
  double _fitZoom(LatLng at) => zoomToFitRadius(
    radiusMeters: _radius,
    latitude: at.latitude,
    widthDp: MediaQuery.sizeOf(context).width,
  );

  void _onRadiusChanged(double value) => setState(() => _radius = value);

  /// **손을 뗄 때 한 번** 원에 맞게 줌을 옮긴다 (이슈 #152 QA).
  ///
  /// 예전에는 반경을 바꿔도 줌이 그대로라 원이 화면을 넘치거나 점처럼
  /// 작아졌다. 끄는 동안 매번 옮기면 지도가 흔들리고 손으로 맞춘 확대도
  /// 덮어쓰므로, 놓았을 때만 맞춘다. 중심은 그대로다 — 핀이 가리키는
  /// 자리가 저장 좌표다
  void _onRadiusChangeEnd(double value) {
    _map?.animateCamera(CameraUpdate.zoomTo(_fitZoom(_center)));
  }

  /// 현재 위치로 카메라를 옮긴다 (이슈 #152).
  ///
  /// 못 얻으면 아무것도 하지 않는다. 위치를 못 얻는 것은 정상적으로
  /// 일어나는 상태다 — 오류 문구로 놀라게 할 일이 아니다.
  Future<void> _moveToCurrentLocation() async {
    final here = await widget.locationService.current();
    if (here == null || !mounted) return;
    Diagnostics.log('picker', '내 위치로 이동 ${here.latitude},${here.longitude}');
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(here.latitude, here.longitude),
        _fitZoom(LatLng(here.latitude, here.longitude)),
      ),
    );
  }

  /// 좌표 없이 들어온 경우, 권한이 있으면 현재 위치로 옮긴다 (이슈 #152).
  ///
  /// **고정 좌표로 먼저 그린 뒤 옮긴다.** 위치를 기다리며 회색 화면을
  /// 보여주지 않기 위해서다 — 못 얻으면 고정 좌표에 그대로 머문다.
  Future<void> _startAtCurrentLocationIfNeeded() async {
    if (widget.args.latitude != null && widget.args.longitude != null) return;
    final here = await widget.locationService.current();
    if (here == null || !mounted) {
      Diagnostics.log('picker', '현재 위치를 얻지 못해 기본 좌표에서 시작한다');
      return;
    }
    Diagnostics.log('picker', '현재 위치에서 시작 ${here.latitude},${here.longitude}');
    setState(() => _center = LatLng(here.latitude, here.longitude));
    await _map?.moveCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(here.latitude, here.longitude),
        _fitZoom(LatLng(here.latitude, here.longitude)),
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
          MapRevealCover(
            screen: 'picker',
            builder: (attach) => GoogleMap(
              onMapCreated: (controller) {
                _map = controller;
                // 다크 스타일이 조용히 사라지는 일이 있다 (이슈 #143)
                unawaited(ensureDarkMapStyle(controller, 'picker'));
                // 다크 타일이 그려질 때까지 밝은 바탕을 가린다 (이슈 #143)
                attach(controller);
                unawaited(_startAtCurrentLocationIfNeeded());
              },
              initialCameraPosition: CameraPosition(
                target: _initialCenter,
                zoom: _fitZoom(_initialCenter),
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
              // **SDK 기본 버튼을 끈다** (이슈 #152). 홈 화면과 같은 판단이다
              // (#98) — 그 버튼은 우상단 고정이라 검색창과 부딪힌다.
              //
              // 예전에는 부딪힘을 `padding` 으로 피했는데, **`GoogleMap.padding`
              // 은 카메라 중심을 옮긴다.** 위 80 을 주면 저장될 좌표가 화면에서
              // 40px 아래로 내려가는데 중앙 고정 핀은 그걸 모른 채 Stack
              // 중앙에 남아, 사용자가 찍은 곳과 저장되는 곳이 갈라졌다.
              myLocationButtonEnabled: false,
              // 기본 확대 버튼은 다크 테마에 맞지 않고, 핀치로 충분하다
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              // **padding 을 주지 않는다.** SDK 컨트롤을 전부 껐으므로 피할
              // 대상이 없고, padding 은 카메라 중심을 옮겨 중앙 고정 핀과
              // 어긋나게 만든다 (위 주석 참조, 이슈 #152).
              //
              // 앞으로 padding 이 필요해지면 **핀도 같은 값만큼 함께** 옮겨야
              // 한다. `design_system_test.dart` 가 이 조합을 막는다.
            ),
          ),

          // 중앙 고정 핀. 지도 조작을 가로막지 않아야 한다.
          //
          // **이 핀이 가리키는 곳이 곧 저장되는 좌표다.** 지도에 padding 이
          // 없으므로 Stack 중앙 = 카메라 중심이고, 둘이 같아야만 사용자가
          // 찍은 자리가 그대로 저장된다 (이슈 #152).
          IgnorePointer(
            child: Center(
              child: Padding(
                // 핀 끝이 정중앙을 가리키도록 올린다.
                //
                // 아이콘 높이(40)만큼 올리면 **상자 바닥**이 중앙에 오는데,
                // `place_outlined` 글리프는 24 격자에서 끝이 y=22 라 상자
                // 바닥보다 2/24 위에 있다. 그만큼 핀이 떠서 실기기에서 저장
                // 좌표보다 10px(4dp) 위를 가리켰다 (이슈 #152 QA).
                // Center 가 패딩까지 포함해 가운데 두므로 차이의 두 배를 뺀다
                padding: const EdgeInsets.only(
                  bottom: _pinSize - 2 * (_pinSize * _pinTipInset),
                ),
                child: Icon(
                  Icons.place_outlined,
                  size: _pinSize,
                  color: semantic.alertEnter,
                ),
              ),
            ),
          ),

          // 내 위치 버튼과 하단 패널을 **한 덩어리로 쌓는다.**
          //
          // 처음엔 `Positioned(bottom: 고정값)` 으로 띄웠다가 패널 뒤로 숨었다.
          // 패널 높이를 숫자로 추정하는 방식은 문구가 한 줄만 늘어도 틀린다 —
          // 쌓아 두면 애초에 가려질 수가 없다.
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // **오른쪽 배치** — 홈과 같은 자리 (docs/06-UX.md).
                // 떠 있는 버튼은 엄지가 닿는 오른쪽에 모은다.
                // 보이는 원보다 넓게 눌린다 — 홈과 같다 (이슈 #155 QA).
                // 넓힌 만큼 바깥 여백에서 뺐다
                Padding(
                  padding: const EdgeInsets.only(
                    right: AppSpacing.sm - AppSpacing.xs,
                    bottom: AppSpacing.sm - AppSpacing.xs,
                  ),
                  child: HitSlop(
                    onTap: _moveToCurrentLocation,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: FloatingActionButton.small(
                      heroTag: 'pickerMyLocation',
                      backgroundColor: AppColors.bgElevated,
                      foregroundColor: AppColors.textPrimary,
                      onPressed: _moveToCurrentLocation,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      child: const Icon(Icons.my_location_outlined),
                    ),
                  ),
                ),
                _PickerPanel(
                  radius: _radius,
                  onRadiusChanged: _onRadiusChanged,
                  onRadiusChangeEnd: _onRadiusChangeEnd,
                  onConfirm: () => widget.onPicked?.call(
                    MapPickResult(
                      latitude: _center.latitude,
                      longitude: _center.longitude,
                      radiusMeters: _radius.round(),
                    ),
                  ),
                ),
              ],
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
                  prefixIcon: const Icon(
                    Icons.search_outlined,
                    size: AppIconSize.standard,
                  ),
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
                          icon: const Icon(
                            Icons.close_outlined,
                            size: AppIconSize.standard,
                          ),
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
                      leading: const Icon(
                        Icons.place_outlined,
                        size: AppIconSize.standard,
                      ),
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
      child: Text(message.keepAll, style: AppTypography.caption),
    );
  }
}

class _PickerPanel extends StatelessWidget {
  const _PickerPanel({
    required this.radius,
    required this.onRadiusChanged,
    required this.onRadiusChangeEnd,
    required this.onConfirm,
  });

  final double radius;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<double> onRadiusChangeEnd;
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
              onChangeEnd: onRadiusChangeEnd,
            ),
            Text(
              '지도를 움직여 핀을 맞추세요'.keepAll,
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
