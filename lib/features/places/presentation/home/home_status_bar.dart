part of '../place_map_home_screen.dart';

// 상단 감시 상태 알약

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
    this.planBadge,
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

  /// 등급 칩 (#294) — 설정 버튼 왼쪽
  final Widget? planBadge;

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
        : context.appColors.textSecondary; // 정상 대기 — 경고색을 쓰지 않는다

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
                Flexible(child: _statusPill(context, semantic, statusColor)),
                // 등급 칩과 설정은 한 묶음 — 오른쪽 끝에 붙어 선다 (#294)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (planBadge != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      planBadge!,
                    ],
                    if (onOpenSettings != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _SettingsButton(onPressed: onOpenSettings!),
                    ],
                  ],
                ),
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

  Widget _statusPill(
    BuildContext context,
    AppSemanticColors semantic,
    Color statusColor,
  ) {
    return Material(
      color: context.appColors.surface,
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
                //
                // **폭도 정해 둔다** (#278). 높이만 주면 이미지를 디코딩하기 전
                // 폭이 0 이라, 디코딩이 끝나는 순간 알약이 로고 폭만큼 늘어났다
                // (원본 100×144 → 높이 24 에서 폭 약 16.7)
                Image.asset(
                  'assets/icon/app_logo_mark.png',
                  height: AppIconSize.standard,
                  width: AppIconSize.standard * 100 / 144,
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
                // ("첫 장소를 등록해주세요"). 같은 말을 두 곳에서 하지 않는다.
                //
                // **감시 상태는 줄이지 않는다** (이슈 #224). 영어에서
                // "Monitoring" 이 "Monit…" 로 잘려 감시 중인지 읽히지 않았다.
                // 공간이 모자라면 오른쪽 오디오 문구가 대신 줄어든다 — 그쪽은
                // 아이콘만으로도 뜻이 통한다.
                Text(
                  isMonitoring
                      ? context.l10n.placeHomeStatusWatching
                      : _isBroken
                      ? context.l10n.placeHomeStatusOff
                      : _isChecking
                      ? context.l10n.placeHomeStatusChecking
                      : context.l10n.placeHomeStatusIdle,
                  style: context.appTextStyles.body.copyWith(
                    color: statusColor,
                  ),
                  maxLines: 1,
                  softWrap: false,
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
                  style: context.appTextStyles.body.copyWith(
                    color: context.appColors.textSecondary.withValues(
                      alpha: 0.5,
                    ),
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
                      : context.appColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    isHeadphoneConnected
                        ? context.l10n.placeHomeAudioHeadphones
                        : context.l10n.placeHomeAudioVibrationOnly,
                    style: context.appTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
