import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';
import '../../../core/domain/alert_sound.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/map/map_corner_mask.dart';
import '../../../core/map/map_reveal_cover.dart';
import '../../../core/map/map_style_guard.dart';
import '../../../core/map/radius_zoom.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/domain/sound_preset_label.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../domain/alert_place.dart';
import '../domain/place_validator.dart';
import 'alert_schedule_editor.dart';
import 'place_card.dart' show showPlaceDeletedSnack;
import 'place_list_controller.dart';
import 'place_empty_state.dart' show placeErrorMessage;
import 'place_map_picker_screen.dart';
import 'place_section_label.dart';
import '../../../core/widgets/app_feedback.dart';

/// 장소 등록/편집 폼 (docs/06-UX.md)
///
/// 위치는 **지도에서 고르는 것이 기본**이다. 좌표 직접 입력은 접어둔
/// 보조 수단으로 남긴다 — 지도 API 키가 없는 빌드에서도 장소를 등록할 수
/// 있어야 하고, 좌표를 정확히 아는 경우가 드물게 있다.
class PlaceFormScreen extends ConsumerStatefulWidget {
  const PlaceFormScreen({
    this.existing,
    this.onSaved,
    this.onDeleted,
    this.onPickOnMap,
    this.onPickSound,
    this.onDescribeSound,
    super.key,
  });

  /// null 이면 신규 등록
  final AlertPlace? existing;
  final VoidCallback? onSaved;

  /// 삭제가 끝났을 때 (이슈 #205). 화면 전환은 라우터가 한다 — `onSaved` 와
  /// 같은 방식이다.
  final VoidCallback? onDeleted;

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
  // 좌표 칸은 소수 6자리로 보여준다 (이슈 #228). 지도에서 고른 값이
  // `37.49789989126091` 처럼 그대로 들어가 칸을 넘쳤다. 6자리면 약 10cm 라
  // 지오펜스 판정에 차이가 없다
  late final _latitude = TextEditingController(
    text: _formatCoordinate(widget.existing?.latitude),
  );
  late final _longitude = TextEditingController(
    text: _formatCoordinate(widget.existing?.longitude),
  );

  /// 칸에 줄여 보여준 좌표의 원래 값.
  ///
  /// **사용자가 칸을 고치지 않았으면 원래 정밀도로 저장한다** — 줄인 값을
  /// 저장하면 편집 화면을 열기만 해도 좌표가 바뀐 것으로 잡혀 "저장하지 않고
  /// 나갈까요?" 가 떴다.
  late double? _preciseLatitude = widget.existing?.latitude;
  late double? _preciseLongitude = widget.existing?.longitude;

  /// 이름 칸 포커스 — 저장이 거절되면 그 칸으로 올라가 키보드를 띄운다 (이슈 #228)
  final _nameFocus = FocusNode();

  /// 폼 스크롤 — 거절된 칸까지 되돌아갈 때 쓴다
  final _scroll = ScrollController();

  /// 위치 칸 — 좌표가 없어 거절되면 여기로 스크롤한다
  final _locationKey = GlobalKey();

  /// 이름 칸 아래에 붙는 오류. 토스트만으로는 어느 칸이 문제인지 몰랐다
  String? _nameError;

  late double _radius = (widget.existing?.radiusMeters ?? 100).toDouble();
  late AlertDirection _direction =
      widget.existing?.direction ?? AlertDirection.enter;
  late bool _soundEnabled = widget.existing?.soundEnabled ?? true;
  late AlertSound _sound = widget.existing?.sound ?? AlertSound.fallback;

  /// 조회로 얻은 알림음 이름. null 이면 잠정값을 쓴다.
  ///
  /// 잠정값은 번역이 필요해 `BuildContext` 가 있어야 만들 수 있다 —
  /// initState 에서는 못 만들므로 build 에서 채운다.
  String? _soundLabel;

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
  static String _fallbackLabel(AppLocalizations l10n, AlertSound sound) =>
      switch (sound) {
        PresetSound(:final preset) => preset.localizedLabel(l10n),
        CustomSoundRef() => l10n.placeFormCustomSound,
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
      // 조회가 끝나기 전에도 무언가 보여야 한다 — 잠정값으로 되돌린다
      _soundLabel = null;
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
    _nameFocus.dispose();
    _scroll.dispose();
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
    final latitude = _latitudeValue;
    final longitude = _longitudeValue;

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
    return showConfirmDialog(
      context,
      title: context.l10n.placeFormLeaveTitle,
      body: context.l10n.placeFormLeaveBody,
      cancelLabel: context.l10n.placeFormKeepEditing,
      confirmLabel: context.l10n.placeFormLeave,
    );
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l10n.placeFormTitleNew : l10n.placeFormTitleEdit),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpacing.md),
          // 폼을 훑어 내리면 키보드가 비켜준다 (이슈 #228). iOS 숫자 자판에는
          // 닫기 키가 없어 좌표를 입력하면 키보드를 내릴 방법이 없었다
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextField(
              controller: _name,
              focusNode: _nameFocus,
              decoration: InputDecoration(
                labelText: l10n.placeFormNameLabel,
                hintText: l10n.placeFormNameHint,
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.done,
              onTapOutside: _dismissKeyboard,
              onChanged: (_) {
                // 고치기 시작하면 오류를 거둔다 — 다 쓸 때까지 빨간 글씨가
                // 남아 있으면 아직 틀린 것처럼 보인다
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: AppSpacing.md),

            PlaceSectionLabel(l10n.placeFormLocationLabel, key: _locationKey),
            OutlinedButton.icon(
              onPressed: widget.onPickOnMap == null ? null : _pickOnMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _hasCoordinates
                    ? l10n.placeFormRepickOnMap
                    : l10n.placeFormPickOnMap,
              ),
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
                latitude: _latitudeValue!,
                longitude: _longitudeValue!,
                radiusMeters: _radius,
                onTap: widget.onPickOnMap == null ? null : _pickOnMap,
              )
            else
              Text(
                context.keepAllText(l10n.placeFormNoLocation),
                style: AppTypography.caption,
              ),

            // 좌표를 직접 아는 경우와, 지도 키 없이 빌드된 경우의 보조 경로.
            // 기본 경로가 아니므로 접어둔다
            ExpansionTile(
              // 지도 카드가 "어디인가"에 답하므로, 펼치기 제목에는
              // **정확한 값**을 보여준다 — 둘의 역할이 다르다
              title: Text(
                _hasCoordinates
                    ? l10n.placeFormCoordinates(_coordinateSummary)
                    : l10n.placeFormCoordinatesManual,
                style: AppTypography.caption,
              ),
              tilePadding: EdgeInsets.zero,
              // 펼칠 때 머티리얼 기본 구분선이 위아래로 생겨 지도 카드 밑에
              // 선이 붙었다 (이슈 #228). 폼의 다른 칸에는 구분선이 없다
              shape: const Border(),
              collapsedShape: const Border(),
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latitude,
                        decoration: InputDecoration(
                          labelText: l10n.placeFormLatitude,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onTapOutside: _dismissKeyboard,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TextField(
                        controller: _longitude,
                        decoration: InputDecoration(
                          labelText: l10n.placeFormLongitude,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onTapOutside: _dismissKeyboard,
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
            //
            // 제목은 다른 칸(위치·알림 시점)과 같은 작은 회색, 값만 오른쪽에
            // 굵게 둔다 — 예전엔 이 제목만 굵은 흰 글자라 위계가 섞였다
            // (디자인 리뷰 #155). 알림음 크기 시트와 같은 배치다
            PlaceSectionLabel(
              l10n.placeFormRadiusLabel,
              trailing: l10n.placeFormRadiusValue(_radius.round()),
            ),
            Slider(
              value: _radius,
              min: PlaceValidator.minRadiusMeters.toDouble(),
              max: PlaceValidator.maxRadiusMeters.toDouble(),
              divisions: 39,
              onChanged: (value) => setState(() => _radius = value),
            ),
            const SizedBox(height: AppSpacing.md),

            PlaceSectionLabel(l10n.placeFormTimingLabel),
            SegmentedButton<AlertDirection>(
              segments: [
                ButtonSegment(
                  value: AlertDirection.enter,
                  icon: const Icon(Icons.login_outlined),
                  label: _SegmentLabel(l10n.placeFormTimingEnter),
                ),
                ButtonSegment(
                  value: AlertDirection.exit,
                  icon: const Icon(Icons.logout_outlined),
                  label: _SegmentLabel(l10n.placeFormTimingExit),
                ),
                ButtonSegment(
                  value: AlertDirection.both,
                  icon: const Icon(Icons.sync_alt_outlined),
                  label: _SegmentLabel(l10n.placeFormTimingBoth),
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

            // 소리 칸도 다른 칸과 같은 제목 줄을 쓴다 (이슈 #228). 예전엔 이
            // 칸만 굵은 흰 제목이라 폼 안에서 위계가 갈렸다 — 제목은 회색
            // 칸 제목, 스위치 줄에는 무엇이 켜지는지를 적는다
            PlaceSectionLabel(l10n.placeFormSoundTitle),
            SwitchListTile(
              title: Text(
                context.keepAllText(l10n.placeFormSoundDescription),
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
                  title: Text(
                    l10n.placeFormSoundLabel,
                    style: AppTypography.body,
                  ),
                  subtitle: Text(
                    _soundLabel ?? _fallbackLabel(l10n, _sound),
                    style: AppTypography.caption,
                  ),
                  trailing: const Icon(Icons.chevron_right_outlined),
                  onTap: _soundEnabled ? _pickSound : null,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                isNew ? l10n.placeFormSubmitNew : l10n.placeFormSubmitSave,
              ),
            ),

            // 삭제는 편집 중인 장소에만 있다. 저장 버튼 **아래**에 옅게 둔다 —
            // 주 동작과 같은 무게로 놓으면 저장하려다 누른다 (이슈 #205).
            // 스와이프를 모르는 사용자도 여기서 찾을 수 있다
            if (!isNew) ...[
              const SizedBox(height: AppSpacing.xs),
              // 주 동작(저장)이 FilledButton 한 자리뿐이어야 위계가 갈리지 않는다
              // (design_system_test) — 삭제는 TextButton 에 옅은 색을 입힌다
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outlined),
                label: Text(l10n.placeFormDelete),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 칸에 보이는 좌표를 숫자로 읽는다. 줄여 보여준 값 그대로면 원래 값을 쓴다
  double? get _latitudeValue => _readCoordinate(_latitude, _preciseLatitude);
  double? get _longitudeValue => _readCoordinate(_longitude, _preciseLongitude);

  static double? _readCoordinate(
    TextEditingController controller,
    double? precise,
  ) {
    final text = controller.text.trim();
    if (precise != null && text == _formatCoordinate(precise)) return precise;
    return double.tryParse(text);
  }

  /// 칸에 넣을 좌표 문자열 — 소수 6자리 (이슈 #228)
  static String _formatCoordinate(double? value) =>
      value == null ? '' : value.toStringAsFixed(6);

  /// 칸 바깥을 누르면 키보드를 내린다 (이슈 #228). iOS 는 기본으로 내려주지
  /// 않아 키보드가 저장 버튼을 덮은 채 남았다
  void _dismissKeyboard(PointerDownEvent _) =>
      FocusManager.instance.primaryFocus?.unfocus();

  bool get _hasCoordinates => _latitudeValue != null && _longitudeValue != null;

  /// 좌표를 화면에 보여줄 때만 만든다 — 로그에는 남기지 않는다
  /// (docs/04-CONVENTIONS.md)
  String get _coordinateSummary {
    final latitude = _latitudeValue;
    final longitude = _longitudeValue;
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
        latitude: _latitudeValue,
        longitude: _longitudeValue,
        radiusMeters: _radius.round(),
      ),
    );
    if (picked == null || !mounted) return;

    // 검색으로 고른 장소 이름을 제안한다 (이슈 #228). **비어 있을 때만** —
    // 사용자가 쓴 이름("회사 앞 정류장")을 검색 결과("강남역")로 덮으면 안 된다
    final suggestedName = picked.placeName?.trim() ?? '';
    final prefillName = suggestedName.isNotEmpty && _name.text.trim().isEmpty;

    setState(() {
      _preciseLatitude = picked.latitude;
      _preciseLongitude = picked.longitude;
      _latitude.text = _formatCoordinate(picked.latitude);
      _longitude.text = _formatCoordinate(picked.longitude);
      // 반경도 지도에서 원을 보며 정한다 — 돌아온 값이 최신이다
      _radius = picked.radiusMeters.toDouble();
      if (prefillName) {
        _name.text = suggestedName;
        _nameError = null;
      }
    });
    Diagnostics.log(
      'place',
      'form location picked ${picked.latitude},${picked.longitude} '
          'radius=${picked.radiusMeters} '
          'namePrefilled=$prefillName suggestedName=${suggestedName.isEmpty ? "none" : suggestedName}',
    );
  }

  /// 편집 화면에서 삭제한다 (이슈 #205).
  ///
  /// 스와이프와 달리 **확인을 한 번 받는다** — 저장하지 않은 편집 내용과
  /// 같은 화면에 있어 버튼이 오탭되기 쉽고, 지운 뒤에는 화면이 닫혀 맥락이
  /// 사라진다. 지운 직후에는 목록에서 "되돌리기"를 준다.
  Future<void> _delete() async {
    final place = widget.existing;
    if (place == null) return;
    final l10n = context.l10n;

    final confirmed = await showConfirmDialog(
      context,
      title: l10n.placeFormDeleteTitle,
      body: l10n.placeFormDeleteBody(place.name),
      cancelLabel: l10n.placeDeleteCancel,
      confirmLabel: l10n.placeSwipeDeleteLabel,
    );
    if (!confirmed || !mounted) return;

    // 화면이 닫힌 뒤에 안내를 띄워야 하므로 지금 잡아둔다
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(placeActionsProvider.notifier);

    setState(() => _saving = true);
    final deleted = await actions.delete(place.id);
    if (!mounted) return;
    setState(() => _saving = false);

    // 지운 장소의 편집 내용은 의미가 없다 — 나갈 때 묻지 않는다
    _leavingAfterSave = true;
    widget.onDeleted?.call();
    if (deleted != null) {
      showPlaceDeletedSnack(messenger, l10n, actions, deleted);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final latitude = _latitudeValue;
    final longitude = _longitudeValue;

    // 좌표가 없으면 저장소까지 가지 않는다. 이름도 함께 비었으면 같이
    // 알린다 — 하나 고치고 다시 눌러야 다음 오류를 보는 일이 없게 한다
    final errors = latitude == null || longitude == null
        ? _rejectWithoutCoordinates()
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

    unawaited(_revealFirstError(errors));
    context.showToast(placeErrorMessage(context.l10n, errors.first));
  }

  List<PlaceValidationError> _rejectWithoutCoordinates() {
    final errors = [
      if (_name.text.trim().isEmpty) PlaceValidationError.emptyName,
      PlaceValidationError.invalidCoordinates,
    ];
    // 저장소를 거치지 않는 거절이라 여기서 남긴다 — 컨트롤러 로그와 같은 형식
    Diagnostics.log(
      'place',
      'place save rejected name=${_name.text} '
          'reason=${errors.map((e) => e.name).join(",")}',
    );
    return errors;
  }

  /// 틀린 칸을 보여준다 (이슈 #228).
  ///
  /// 토스트만 뜨고 칸에는 아무 표시가 없어, 폼을 내려 둔 상태에서는 무엇을
  /// 고쳐야 하는지 찾아 올라가야 했다. 이름 칸에 오류를 붙이고, 화면에서
  /// 첫 번째로 틀린 칸까지 스크롤한다.
  Future<void> _revealFirstError(List<PlaceValidationError> errors) async {
    final nameMissing = errors.contains(PlaceValidationError.emptyName);
    setState(() {
      _nameError = nameMissing
          ? placeErrorMessage(context.l10n, PlaceValidationError.emptyName)
          : null;
    });

    const duration = Duration(milliseconds: 250);
    if (nameMissing) {
      // 이름 칸은 맨 위다. `ensureVisible` 을 쓰지 않는 이유 — 목록이 게으르게
      // 그려져, 저장 버튼까지 내려온 상태에서는 이름 칸이 이미 사라져 찾을 수 없다
      if (_scroll.hasClients) {
        await _scroll.animateTo(0, duration: duration, curve: Curves.easeOut);
      }
      // 돌아온 칸에 바로 쓸 수 있게 키보드를 올린다
      if (mounted) _nameFocus.requestFocus();
      return;
    }

    if (errors.contains(PlaceValidationError.invalidCoordinates)) {
      final location = _locationKey.currentContext;
      if (location != null) {
        await Scrollable.ensureVisible(
          location,
          duration: duration,
          curve: Curves.easeOut,
        );
      } else if (_scroll.hasClients) {
        // 위치 칸도 맨 위 근처라 꼭대기로 올리면 보인다
        await _scroll.animateTo(0, duration: duration, curve: Curves.easeOut);
      }
    }
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
                      unawaited(ensureDarkMapStyle(controller, 'form'));
                      // 다크 타일이 그려질 때까지 밝은 바탕을 가린다 (이슈 #143)
                      attach(controller);
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
              ),
              // `ClipRRect` 가 네이티브 지도 뷰를 자르지 못한다 (이슈 #142)
              IgnorePointer(
                child: CustomPaint(
                  painter: const MapCornerMask(
                    color: AppColors.bgBase,
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
                    border: Border.all(color: AppColors.bgElevated),
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
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}
