import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/map_style.dart';
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
  const PlaceMapPickerScreen({required this.args, this.onPicked, super.key});

  final MapPickArgs args;

  /// 선택 완료. 라우터가 화면을 닫으며 결과를 돌려준다
  final ValueChanged<MapPickResult>? onPicked;

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

  LatLng get _initialCenter {
    final latitude = widget.args.latitude;
    final longitude = widget.args.longitude;
    if (latitude == null || longitude == null) {
      return PlaceMapPickerScreen._fallback;
    }
    return LatLng(latitude, longitude);
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
