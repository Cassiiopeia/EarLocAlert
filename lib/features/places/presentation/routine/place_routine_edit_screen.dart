import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/diagnostics.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/text/keep_all.dart';
import '../../../../core/ui/components/grouped_list_row.dart';
import '../../../../core/ui/components/grouped_list_section.dart';
import '../../../../core/ui/feedback/app_feedback.dart';
import '../../../../core/ui/foundation/app_color_palette.dart';
import '../../../../core/ui/foundation/app_spacing.dart';
import '../../domain/alert_place.dart';
import '../../domain/place_routine.dart';
import '../place_list_controller.dart';
import '../place_routine_controller.dart';

/// 루틴 만들기·고치기 (#315): 이름, 나머지 끄기, 장소 고르기, 저장·지우기
///
/// 화면 로컬 값(이름·고른 장소)은 setState (결정 069). 저장 순간 저장소로 넘김
class PlaceRoutineEditScreen extends ConsumerStatefulWidget {
  const PlaceRoutineEditScreen({
    this.existing,
    required this.onFinished,
    super.key,
  });

  /// null 이면 새 루틴
  final PlaceRoutine? existing;

  /// 저장·지우기 뒤 나가기 (화면 이동은 라우터)
  final VoidCallback onFinished;

  @override
  ConsumerState<PlaceRoutineEditScreen> createState() =>
      _PlaceRoutineEditScreenState();
}

class _PlaceRoutineEditScreenState
    extends ConsumerState<PlaceRoutineEditScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final Set<String> _selectedPlaceIds = {...?widget.existing?.placeIds};
  late bool _isExclusive = widget.existing?.isExclusive ?? false;

  /// 저장 중 (버튼 중복 방지)
  bool _isSaving = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(List<AlertPlace> places) async {
    final l10n = context.l10n;
    // 지운 장소 id 는 저장하지 않음 (지금 있는 장소 순서대로)
    final placeIds = [
      for (final place in places)
        if (_selectedPlaceIds.contains(place.id)) place.id,
    ];
    setState(() => _isSaving = true);
    try {
      final errors = await ref
          .read(placeRoutineActionsProvider.notifier)
          .save(
            existing: widget.existing,
            name: _name.text,
            placeIds: placeIds,
            isExclusive: _isExclusive,
          );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _nameError = errors.contains(PlaceRoutineValidationError.emptyName)
            ? l10n.routineNameRequired
            : null;
      });
      if (errors.contains(PlaceRoutineValidationError.noPlaces)) {
        context.showToast(l10n.routinePlacesRequired);
      }
      if (errors.isEmpty) widget.onFinished();
    } on Object catch (error) {
      // 저장 실패 시 버튼을 되살리고 사유를 남김
      Diagnostics.log('routine', 'save failed error=$error');
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showToast(l10n.routineSaveFailed);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final isConfirmed = await showConfirmDialog(
      context,
      title: context.l10n.routineDeleteTitle,
      body: context.l10n.routineDeleteBody,
      cancelLabel: context.l10n.routineCancel,
      confirmLabel: context.l10n.routineDelete,
    );
    if (!isConfirmed || !mounted) return;
    await ref.read(placeRoutineActionsProvider.notifier).delete(existing);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final places =
        ref.watch(placeListProvider).valueOrNull ?? const <AlertPlace>[];
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l10n.routineNewTitle : l10n.routineEditTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextField(
              controller: _name,
              maxLength: PlaceRoutine.maxNameLength,
              decoration: InputDecoration(
                labelText: l10n.routineNameLabel,
                hintText: l10n.routineExampleCommute,
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            GroupedListSection(
              children: [
                GroupedListRow.toggle(
                  icon: Icons.toggle_off_outlined,
                  title: l10n.routineExclusiveTitle,
                  subtitle: l10n.routineExclusiveSubtitle,
                  value: _isExclusive,
                  onChanged: (value) => setState(() => _isExclusive = value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            GroupedListSection(
              header: l10n.routinePlacesHeader(_selectedPlaceIds.length),
              children: [
                for (final place in places)
                  GroupedListRow.toggle(
                    icon: Icons.place_outlined,
                    title: place.name,
                    value: _selectedPlaceIds.contains(place.id),
                    onChanged: (isSelected) => setState(() {
                      if (isSelected) {
                        _selectedPlaceIds.add(place.id);
                      } else {
                        _selectedPlaceIds.remove(place.id);
                      }
                    }),
                  ),
              ],
            ),
            if (places.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  context.keepAllText(l10n.routineNoPlacesYet),
                  style: context.appTextStyles.caption,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _isSaving ? null : () => _save(places),
              child: Text(l10n.routineSave),
            ),
            if (!isNew) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: _isSaving ? null : _delete,
                icon: const Icon(Icons.delete_outlined),
                label: Text(l10n.routineDelete),
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
