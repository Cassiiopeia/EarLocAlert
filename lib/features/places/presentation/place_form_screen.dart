import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';
import '../../../core/domain/alert_sound.dart';
import '../../../core/map/map_corner_mask.dart';
import '../../../core/map/map_style_guard.dart';
import '../../../core/map/radius_zoom.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/text/keep_all.dart';
import '../domain/alert_place.dart';
import '../domain/place_validator.dart';
import 'alert_schedule_editor.dart';
import 'place_list_controller.dart';
import 'place_empty_state.dart' show placeErrorMessage;
import 'place_map_picker_screen.dart';

/// 장소 등록/편집 폼 (docs/06-UX.md)
///
/// 위치는 **지도에서 고르는 것이 기본**이다. 좌표 직접 입력은 접어둔
/// 보조 수단으로 남긴다 — 지도 API 키가 없는 빌드에서도 장소를 등록할 수
/// 있어야 하고, 좌표를 정확히 아는 경우가 드물게 있다.
class PlaceFormScreen extends ConsumerStatefulWidget {
  const PlaceFormScreen({
    this.existing,
    this.onSaved,
    this.onPickOnMap,
    this.onPickSound,
    this.onDescribeSound,
    super.key,
  });

  /// null 이면 신규 등록
  final AlertPlace? existing;
  final VoidCallback? onSaved;

  /// 지도 화면을 열고 선택 결과를 돌려준다.
  ///
  /// 화면 전환은 라우터가 한다 — 폼이 `Navigator` 를 직접 부르지 않는다
  /// (docs/02-ARCHITECTURE.md).
  final Future<MapPickResult?> Function(MapPickArgs args)? onPickOnMap;

  /// 알림음 선택 시트를 열고 고른 값을 돌려준다 (이슈 #121).
  ///
  /// 콜백인 이유는 `places` 가 `sounds` 를 import 할 수 없기 때문이다
  /// (규칙 1). 배선은 라우터가 한다 — `onPickOnMap` 과 같은 방식이다.
  final Future<AlertSound?> Function(AlertSound current)? onPickSound;

  /// 알림음의 표시 이름을 얻는다 (이슈 #121).
  ///
  /// **프리셋은 폼이 직접 알지만 사용자 음원의 파일명은 모른다** —
  /// 그 이름은 `sounds` 의 저장소에 있고, `places` 는 그것을 볼 수 없다.
  /// 없으면 "내 음원" 으로 표시한다.
  final Future<String> Function(AlertSound sound)? onDescribeSound;

  @override
  ConsumerState<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends ConsumerState<PlaceFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _latitude = TextEditingController(
    text: widget.existing?.latitude.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.existing?.longitude.toString() ?? '',
  );

  late double _radius = (widget.existing?.radiusMeters ?? 100).toDouble();
  late AlertDirection _direction =
      widget.existing?.direction ?? AlertDirection.enter;
  late bool _soundEnabled = widget.existing?.soundEnabled ?? true;
  late AlertSound _sound = widget.existing?.sound ?? AlertSound.fallback;

  /// 화면에 보여줄 알림음 이름. 조회 전에는 잠정값을 쓴다
  late String _soundLabel = _fallbackLabel(_sound);

  /// 빈 목록이면 항상 알림 (이슈 #81)
  late List<AlertSchedule> _schedules =
      widget.existing?.schedules ?? const <AlertSchedule>[];

  bool _saving = false;

  /// 저장 버튼으로 나가는 중인가 (이슈 #112).
  ///
  /// 저장이 끝나면 폼과 저장된 값이 같아지지만, 그 판정을 기다리지 않고
  /// 곧바로 화면이 닫히므로 이 깃발로 확인 창을 건너뛴다.
  bool _leavingAfterSave = false;

  @override
  void initState() {
    super.initState();
    // **입력이 바뀌면 다시 그린다** (이슈 #112).
    //
    // `PopScope.canPop` 은 빌드 시점에 평가되므로, 텍스트를 고쳐도
    // 리빌드되지 않으면 "바꾼 것 없음"으로 남아 확인 없이 나가버린다.
    // 필드마다 `onChanged` 를 다는 대신 컨트롤러를 한 곳에서 듣는다 —
    // 필드를 추가할 때 빠뜨릴 여지를 없앤다.
    for (final controller in [_name, _latitude, _longitude]) {
      controller.addListener(_onFieldChanged);
    }
    _refreshSoundLabel();
  }

  /// 프리셋은 여기서 바로 알 수 있다. 사용자 음원은 이름을 모르므로
  /// 조회 콜백이 채워줄 때까지 이 값이 쓰인다.
  static String _fallbackLabel(AlertSound sound) => switch (sound) {
    PresetSound(:final preset) => preset.label,
    CustomSoundRef() => '내 음원',
  };

  Future<void> _refreshSoundLabel() async {
    final describe = widget.onDescribeSound;
    if (describe == null) return;
    try {
      final label = await describe(_sound);
      if (mounted) setState(() => _soundLabel = label);
    } on Object {
      // 이름을 못 읽어도 잠정값이 남는다 — 화면이 비지 않는다
    }
  }

  Future<void> _pickSound() async {
    final pick = widget.onPickSound;
    if (pick == null) return;
    final picked = await pick(_sound);
    if (picked == null || !mounted) return;
    setState(() {
      _sound = picked;
      // 조회가 끝나기 전에도 무언가 보여야 한다
      _soundLabel = _fallbackLabel(picked);
    });
    await _refreshSoundLabel();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [_name, _latitude, _longitude]) {
      controller.removeListener(_onFieldChanged);
    }
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  /// 저장하지 않은 변경이 있는가 (이슈 #112).
  ///
  /// **편집과 신규 등록의 기준이 다르다.** 편집은 원본과 달라졌는지를 보고,
  /// 신규는 무언가 입력했는지를 본다 — 빈 폼을 열었다 닫는 것은 버릴 것이
  /// 없으므로 묻지 않는다.
  bool get _hasUnsavedChanges {
    final existing = widget.existing;
    if (existing == null) {
      return _name.text.trim().isNotEmpty ||
          _latitude.text.trim().isNotEmpty ||
          _longitude.text.trim().isNotEmpty ||
          _schedules.isNotEmpty ||
          // 신규 기본값과 달라졌으면 사용자가 건드린 것이다
          _radius.round() != 100 ||
          _direction != AlertDirection.enter ||
          !_soundEnabled ||
          _sound != AlertSound.fallback;
    }

    // 좌표는 문자열로 비교하면 `37.4` 와 `37.40` 이 다르게 잡힌다.
    // 숫자로 바꿔서 본다
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());

    return _name.text.trim() != existing.name ||
        latitude != existing.latitude ||
        longitude != existing.longitude ||
        _radius.round() != existing.radiusMeters ||
        _direction != existing.direction ||
        _soundEnabled != existing.soundEnabled ||
        _sound != existing.sound ||
        !_sameSchedules(_schedules, existing.schedules);
  }

  /// 시간대 목록이 같은가. 순서까지 같아야 같은 것으로 본다 —
  /// 사용자가 순서를 바꿨다면 그것도 변경이다.
  bool _sameSchedules(List<AlertSchedule> a, List<AlertSchedule> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 나가도 되는지 묻는다 (이슈 #112).
  ///
  /// **기본 선택은 "계속 편집"이다.** 실수로 나가려던 사용자가 다시
  /// 실수로 버리는 것을 막는다.
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장하지 않고 나갈까요?'),
        content: Text('지금까지 바꾼 내용은 사라집니다.'.keepAll),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 편집'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return PopScope(
      // 바꾼 것이 없으면 그냥 나간다 — 안 바꿨는데 묻는 것은 방해다
      canPop: !_hasUnsavedChanges || _leavingAfterSave,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // 다이얼로그를 열기 전에 Navigator 를 잡아둔다 — 확인을 기다리는
        // 사이 이 위젯이 사라질 수 있고, 그때 context 를 쓰면 안 된다
        final navigator = Navigator.of(context);
        if (!await _confirmDiscard()) return;
        if (!mounted) return;
        navigator.pop();
      },
      child: _buildForm(isNew),
    );
  }

  Widget _buildForm(bool isNew) {
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? '장소 등록' : '장소 편집')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '예: 내릴 정류장, 약속 장소',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),

            Text('위치', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: widget.onPickOnMap == null ? null : _pickOnMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(_hasCoordinates ? '지도에서 다시 선택' : '지도에서 선택'),
            ),
            const SizedBox(height: AppSpacing.xs),

            // **고른 자리를 지도로 확인시킨다** (이슈 #155).
            //
            // 좌표 숫자는 "여기가 맞나"에 답하지 않는다. 확인하려면 지도를
            // 다시 열어야 했고, 반경을 바꿔도 그 범위가 어디까지인지
            // 보이지 않았다.
            //
            // **좌표가 없으면 그리지 않는다** — 지도 키 없이 빌드된
            // 경우에도 폼은 동작해야 한다 (알림 화면과 같은 규칙).
            if (_hasCoordinates)
              _LocationPreview(
                latitude: double.parse(_latitude.text.trim()),
                longitude: double.parse(_longitude.text.trim()),
                radiusMeters: _radius,
                onTap: widget.onPickOnMap == null ? null : _pickOnMap,
              )
            else
              Text('아직 위치를 고르지 않았습니다'.keepAll, style: AppTypography.caption),

            // 좌표를 직접 아는 경우와, 지도 키 없이 빌드된 경우의 보조 경로.
            // 기본 경로가 아니므로 접어둔다
            ExpansionTile(
              // 지도 카드가 "어디인가"에 답하므로, 펼치기 제목에는
              // **정확한 값**을 보여준다 — 둘의 역할이 다르다
              title: Text(
                _hasCoordinates ? '좌표  $_coordinateSummary' : '좌표 직접 입력',
                style: AppTypography.caption,
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latitude,
                        decoration: const InputDecoration(labelText: '위도'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TextField(
                        controller: _longitude,
                        decoration: const InputDecoration(labelText: '경도'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 반경 — 슬라이더 값이 즉시 보여야 한다.
            // 지도가 붙으면 반경 원이 실시간으로 함께 커진다 (docs/06-UX.md)
            Text(
              '알림 반경 ${_radius.round()}m',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _radius,
              min: PlaceValidator.minRadiusMeters.toDouble(),
              max: PlaceValidator.maxRadiusMeters.toDouble(),
              divisions: 39,
              onChanged: (value) => setState(() => _radius = value),
            ),
            const SizedBox(height: AppSpacing.md),

            Text('알림 시점', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<AlertDirection>(
              segments: const [
                ButtonSegment(
                  value: AlertDirection.enter,
                  icon: Icon(Icons.login_outlined),
                  label: Text('도착'),
                ),
                ButtonSegment(
                  value: AlertDirection.exit,
                  icon: Icon(Icons.logout_outlined),
                  label: Text('출발'),
                ),
                ButtonSegment(
                  value: AlertDirection.both,
                  icon: Icon(Icons.sync_alt_outlined),
                  label: Text('둘 다'),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (selection) =>
                  setState(() => _direction = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),

            // 알림 시점(무엇을) 바로 아래에 시간대(언제)를 둔다 — 두 축이
            // 이어져 읽힌다 (이슈 #81)
            AlertScheduleEditor(
              schedules: _schedules,
              onChanged: (next) => setState(() => _schedules = next),
            ),
            const SizedBox(height: AppSpacing.md),

            SwitchListTile(
              title: Text('이어폰 소리 알림', style: AppTypography.body),
              subtitle: Text(
                '이어폰(줄·블루투스)이 연결된 경우에만 소리가 납니다.\n스피커로는 절대 소리가 나지 않습니다.'.keepAll,
                style: AppTypography.caption,
              ),
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),

            // 소리를 켠 다음에 무슨 소리인지 고르는 순서다 (이슈 #121).
            // 꺼져 있어도 숨기지 않는다 — 숨기면 스위치를 켤 때 화면이 튄다
            if (widget.onPickSound != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Opacity(
                opacity: _soundEnabled ? 1 : 0.5,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text('알림음', style: AppTypography.body),
                  subtitle: Text(_soundLabel, style: AppTypography.caption),
                  trailing: const Icon(Icons.chevron_right_outlined),
                  onTap: _soundEnabled ? _pickSound : null,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(isNew ? '등록' : '저장'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasCoordinates =>
      double.tryParse(_latitude.text.trim()) != null &&
      double.tryParse(_longitude.text.trim()) != null;

  /// 좌표를 화면에 보여줄 때만 만든다 — 로그에는 남기지 않는다
  /// (docs/04-CONVENTIONS.md)
  String get _coordinateSummary {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null || longitude == null) return '';
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  Future<void> _pickOnMap() async {
    // **떠나기 전에 입력 칸의 포커스를 푼다.** 이름을 쓰다가 지도로 가면
    // 돌아올 때 Navigator 가 이 화면이 기억한 칸에 포커스를 되돌려 키보드가
    // 다시 올라왔다 — 방금 고른 위치의 미리보기를 키보드가 덮는다
    // (이슈 #155 QA).
    //
    // `FocusScope.of(context).unfocus()` 로는 안 된다. 화면의 포커스
    // 범위만 비우고 "마지막 칸" 기억은 남겨, 실기기에서 그대로 재현됐다.
    // 칸 자체를 풀어야 기억이 지워진다
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await widget.onPickOnMap!(
      MapPickArgs(
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        radiusMeters: _radius.round(),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _latitude.text = picked.latitude.toString();
      _longitude.text = picked.longitude.toString();
      // 반경도 지도에서 원을 보며 정한다 — 돌아온 값이 최신이다
      _radius = picked.radiusMeters.toDouble();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());

    final errors = latitude == null || longitude == null
        ? [PlaceValidationError.invalidCoordinates]
        : await ref
              .read(placeActionsProvider.notifier)
              .save(
                id: widget.existing?.id,
                name: _name.text,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: _radius.round(),
                direction: _direction,
                soundEnabled: _soundEnabled,
                sound: _sound,
                schedules: _schedules,
              );

    if (!mounted) return;
    setState(() => _saving = false);

    if (errors.isEmpty) {
      // 저장 직후의 이탈은 묻지 않는다 (이슈 #112)
      _leavingAfterSave = true;
      widget.onSaved?.call();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(placeErrorMessage(errors.first).keepAll)),
    );
  }
}

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
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 지도는 조작을 받지 않는다 — 탭은 위의 GestureDetector 가 받는다
            IgnorePointer(
              child: GoogleMap(
                onMapCreated: (controller) {
                  _map = controller;
                  // 다크 스타일이 조용히 사라지는 일이 있다 (이슈 #143)
                  unawaited(ensureDarkMapStyle(controller, 'form'));
                },
                initialCameraPosition: CameraPosition(
                  target: target,
                  zoom: zoomForRadiusWider(widget.radiusMeters),
                ),
                style: MapStyle.dark,
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
            // `ClipRRect` 가 네이티브 지도 뷰를 자르지 못한다 (이슈 #142)
            IgnorePointer(
              child: CustomPaint(
                painter: const MapCornerMask(
                  color: AppColors.bgBase,
                  radius: AppRadius.small,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
