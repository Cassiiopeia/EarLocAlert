import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/map/map_style_guard.dart';
import '../../../core/map/map_corner_mask.dart';
import '../../../core/map/radius_zoom.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/map_style.dart';
import '../domain/alert_session.dart';
import '../domain/audio_route.dart';

/// 지도 카드 높이 (이슈 #142)
const double _mapCardHeight = 400;

/// 지도가 있을 때의 해제 버튼 높이.
///
/// **이 값이 이 화면의 안전 하한이다.** 더 줄이면 보기는 좋아지지만
/// 버스에서 화면을 보지 않고 누를 때 빗나간다. 테스트가 이 값을 지킨다.
const double _dismissHeightWithMap = 84;

/// 지도가 없을 때의 해제 버튼 높이 — 남는 자리를 버튼이 가져간다
const double _dismissHeightAlone = 260;

/// 알림 화면 (docs/06-UX.md)
///
/// **이 앱의 사용 시간 99% 가 이 화면이다.**
///
/// 설계 전제:
/// - 버스 안, 한 손으로, 졸다 깬 직후
/// - 주변에 사람이 있어 소리를 낼 수 없다
/// - 몇 초 안에 꺼야 한다는 압박
///
/// 그래서 **누를 수 있는 것이 해제 버튼 하나뿐**이다. 스와이프를 쓰지
/// 않는다 (docs/10-DECISIONS.md 016).
///
/// 가운데에 장소 지도를 둔다 (이슈 #142). 장소명만으로는 어디에 도착했는지
/// 감이 오지 않는다는 요청이었다. 그만큼 해제 버튼을 줄였지만 **보이는
/// 크기와 터치 영역을 분리해** 급할 때 빗나가지 않게 했다.
class AlertScreen extends StatelessWidget {
  const AlertScreen({
    required this.session,
    required this.onDismiss,
    this.soundFailed = false,
    super.key,
  });

  final AlertSession session;
  final VoidCallback onDismiss;

  /// 소리를 내려 했으나 실패해 진동으로 떨어졌는가
  final bool soundFailed;

  bool get _isExit => session.direction == AlertDirection.exit;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final accent = _isExit ? semantic.alertExit : semantic.alertEnter;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _AlertInfo(
                session: session,
                accent: accent,
                isExit: _isExit,
                soundFailed: soundFailed,
              ),
            ),
            if (session.hasMapLocation)
              _PlaceMapCard(
                session: session,
                accent: accent,
                // 기본 마커는 빨간색이라 이 화면의 색과 부딪힌다.
                // 진입·이탈 색과 결이 맞는 것으로 고른다
                markerHue: _isExit
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueCyan,
              ),
            // **지도가 없으면 버튼이 원래 크기로 돌아간다.** 카드가 빠진
            // 자리에 회색 사각형이나 오류 문구를 두지 않는다 — 알림
            // 화면에서 사용자가 읽어야 할 것은 장소와 끄는 방법뿐이다.
            _DismissButton(
              onPressed: onDismiss,
              height: session.hasMapLocation
                  ? _dismissHeightWithMap
                  : _dismissHeightAlone,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertInfo extends StatelessWidget {
  const _AlertInfo({
    required this.session,
    required this.accent,
    required this.isExit,
    required this.soundFailed,
  });

  final AlertSession session;
  final Color accent;
  final bool isExit;
  final bool soundFailed;

  @override
  Widget build(BuildContext context) {
    // **자리가 모자라면 이 영역 전체를 줄인다** (이슈 #145 QA).
    //
    // 지도 카드와 해제 버튼은 크기가 정해져 있고, 남은 높이에 이 영역이
    // 들어가야 한다. 장소명이 두 줄이 되면 넘쳤는데, 넘친 자리가 하필 맨
    // 아래 소리 상태 칩이라 "소리가 새지 않았다"는 표시만 조용히 사라졌다.
    // 해제 버튼을 줄이는 것은 안 되고(#142 안전선), 칩을 빼는 것도 안
    // 되므로 넘칠 때만 비율을 유지한 채 축소한다. 넉넉하면 그대로다.
    //
    // 폭은 고정해서 넘긴다 — FittedBox 는 자식에게 무한 폭을 주므로
    // 그대로 두면 장소명이 줄바꿈 없이 한 줄로 늘어난 뒤 작게 줄어든다
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: constraints.maxWidth, child: _content()),
      ),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 색만으로 구분하지 않는다 — 아이콘·텍스트를 함께 쓴다 (색각 이상 대응)
          Icon(
            isExit ? Icons.logout_outlined : Icons.login_outlined,
            size: AppIconSize.hero,
            color: accent,
          ),
          const SizedBox(height: AppSpacing.md),

          // 가장 큰 글자 — 여러 곳을 등록했으면 "어디인지"가 첫 정보다
          Text(
            session.placeName,
            style: AppTypography.alertPlaceName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isExit ? '떠났습니다' : '도착했습니다',
            style: AppTypography.screenTitle.copyWith(color: accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          // **언제 울렸는지는 장소 다음으로 중요하다** (이슈 #142).
          // caption 이라 눈에 안 들어온다는 지적을 받고 키웠다.
          Text(_formatTime(session.startedAt), style: AppTypography.alertTime),

          const SizedBox(height: AppSpacing.lg),
          _AudioRouteBadge(route: session.audioRoute, soundFailed: soundFailed),
        ],
      ),
    );
  }

  /// 표시 직전에만 로컬 시각으로 바꾼다 (docs/04-CONVENTIONS.md)
  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final hour = local.hour;
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$period $displayHour:$minute';
  }
}

/// 오디오 경로 표시.
///
/// **이 앱을 쓰는 이유가 이것이다.** 사용자는 소리가 스피커로 새지 않았다는
/// 것을 확인하고 싶어 한다 (docs/06-UX.md).
class _AudioRouteBadge extends StatelessWidget {
  const _AudioRouteBadge({required this.route, required this.soundFailed});

  final AudioRoute route;
  final bool soundFailed;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final isHeadphones = route == AudioRoute.headphones;

    final label = switch ((isHeadphones, soundFailed)) {
      (true, _) => '이어폰으로 알림 중',
      (false, true) => '소리를 재생하지 못해 진동으로 알림 중',
      (false, false) => '진동으로만 알림 중',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHeadphones ? Icons.headphones_outlined : Icons.vibration_outlined,
            size: AppIconSize.inline,
            color: isHeadphones
                ? semantic.audioBluetooth
                : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(label, style: AppTypography.caption)),
        ],
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onPressed, required this.height});

  final VoidCallback onPressed;

  /// 보이는 높이. 실제로 눌리는 범위는 이보다 넓다 — 아래 주석 참조
  final double height;

  @override
  Widget build(BuildContext context) {
    // **보이는 크기와 누를 수 있는 범위를 분리한다** (이슈 #142).
    //
    // 지도를 넣느라 버튼을 줄였는데, 이 버튼은 버스에서 화면을 보지 않고
    // 엄지로 누르는 용도다. 빗나가면 진동이 계속되고 그 경험이 반복되면
    // 앱을 지운다. 주변 여백까지 탭을 받아 눈에 보이는 것보다 넉넉하게
    // 잡는다 — 여백에는 누를 것이 없으므로 오작동 위험이 없다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
            child: Text(
              '알림 끄기',
              style: AppTypography.displayLarge.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 도착한 장소의 지도 (이슈 #142)
///
/// **조작할 수 없다.** 확대도 이동도 안 되고 탭도 받지 않는다 — 해제
/// 버튼 옆에 새 터치 타겟을 만들면 급할 때 엉뚱한 것을 누른다.
///
/// lite mode 로 그린다. 살아있는 렌더러가 아니라 정적 비트맵 한 장이라
/// 전력을 거의 쓰지 않는다. 이 화면은 알림이 울리는 동안 켜져 있으므로
/// 그 차이가 그대로 배터리로 간다.
class _PlaceMapCard extends StatelessWidget {
  const _PlaceMapCard({
    required this.session,
    required this.accent,
    required this.markerHue,
  });

  final AlertSession session;
  final Color accent;
  final double markerHue;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(session.latitude!, session.longitude!);
    final radiusMeters = session.radiusMeters!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        height: _mapCardHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: GoogleMap(
                  // 다크 스타일이 조용히 사라지는 일이 있다 (이슈 #143)
                  onMapCreated: (controller) =>
                      unawaited(ensureDarkMapStyle(controller, 'alert')),
                  initialCameraPosition: CameraPosition(
                    target: target,
                    zoom: zoomForRadius(radiusMeters.toDouble()),
                  ),
                  style: MapStyle.dark,
                  liteModeEnabled: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('alert_place'),
                      position: target,
                      icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('alert_radius'),
                      center: target,
                      radius: radiusMeters.toDouble(),
                      strokeWidth: 2,
                      strokeColor: accent,
                      fillColor: accent.withValues(alpha: 0.16),
                    ),
                  },
                  zoomGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  // **내 위치를 그린다** (이슈 #144). 반경 원 안에 내가
                  // 들어와 있는지가 보여야 알림을 납득한다 — 반경 밖인데
                  // 울린 적이 있어(#131) 그 확인 수단이 필요하다.
                  myLocationEnabled: true,
                  // 버튼은 넣지 않는다. 해제 버튼 근처에 터치 타겟을
                  // 만들지 않는다는 원칙은 그대로다
                  myLocationButtonEnabled: false,
                ),
              ),
            ),
            // **오른쪽 아래에 둔다.** 왼쪽 아래는 Google 워터마크
            // 자리라 겹치면 둘 다 안 읽힌다 (지울 수도 없다).
            Positioned(
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: _RadiusChip(radiusMeters: radiusMeters),
            ),

            // **네이티브 지도 뷰에는 ClipRRect 가 먹지 않는다.**
            // 지도는 Flutter 가 그리는 레이어가 아니라 그 위에 얹힌
            // 별도 표면이라 잘리지 않고 직사각형으로 남는다. 모서리
            // 바깥을 배경색으로 덮어 둥글어 보이게 한다.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: MapCornerMask(
                    color: AppColors.bgBase,
                    radius: AppRadius.card,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 반경 표시 — "이만큼 안에 들어왔다"를 숫자로 확인시킨다
class _RadiusChip extends StatelessWidget {
  const _RadiusChip({required this.radiusMeters});

  final int radiusMeters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgBase.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('반경 ${radiusMeters}m', style: AppTypography.caption),
    );
  }
}
