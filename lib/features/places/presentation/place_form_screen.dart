import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/alert_direction.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/alert_place.dart';
import '../domain/place_validator.dart';
import 'place_list_controller.dart';
import 'place_list_screen.dart' show placeErrorMessage;

/// 장소 등록/편집 폼 (docs/06-UX.md)
///
/// 좌표 직접 입력은 **지도 연결 전 임시 수단**이다. Google Maps API 키가
/// 준비되면 "지도에서 선택"으로 교체한다 — 이름·반경·방향·소리는 그대로다.
class PlaceFormScreen extends ConsumerStatefulWidget {
  const PlaceFormScreen({this.existing, this.onSaved, super.key});

  /// null 이면 신규 등록
  final AlertPlace? existing;
  final VoidCallback? onSaved;

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

            // 지도 연결 전 임시 입력. 사용자 안내를 명시한다
            Text('위치 좌표', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('지도에서 선택하는 기능은 준비 중입니다', style: AppTypography.caption),
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

            SwitchListTile(
              title: Text('이어폰 소리 알림', style: AppTypography.body),
              subtitle: Text(
                '블루투스 이어폰이 연결된 경우에만 소리가 납니다.\n스피커로는 절대 소리가 나지 않습니다.',
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
