import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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

  /// 빈 목록이면 항상 알림 (이슈 #81)
  late List<AlertSchedule> _schedules =
      widget.existing?.schedules ?? const <AlertSchedule>[];

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

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
            Text(
              _hasCoordinates ? _coordinateSummary : '아직 위치를 고르지 않았습니다',
              style: AppTypography.caption,
            ),

            // 좌표를 직접 아는 경우와, 지도 키 없이 빌드된 경우의 보조 경로.
            // 기본 경로가 아니므로 접어둔다
            ExpansionTile(
              title: Text('좌표 직접 입력', style: AppTypography.caption),
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
                '이어폰(줄·블루투스)이 연결된 경우에만 소리가 납니다.\n스피커로는 절대 소리가 나지 않습니다.',
                style: AppTypography.caption,
              ),
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),
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
                schedules: _schedules,
              );

    if (!mounted) return;
    setState(() => _saving = false);

    if (errors.isEmpty) {
      widget.onSaved?.call();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(placeErrorMessage(errors.first))));
  }
}
