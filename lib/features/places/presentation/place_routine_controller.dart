import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/diagnostics/log_format.dart';
import '../../../core/domain/id_generator.dart';
import '../data/place_repository_provider.dart';
import '../data/place_routine_providers.dart';
import '../domain/alert_place.dart';
import '../domain/place_routine.dart';

part 'place_routine_controller.g.dart';

/// 루틴 저장 거절 사유 2가지: 이름 없음, 장소 없음
enum PlaceRoutineValidationError { emptyName, noPlaces }

/// 루틴 조작 (#315): 저장 (검증 > 저장 > 기록), 지우기, 누르기 (장소 한 번에 켜고 끄기)
///
/// 만들기 등급 확인은 진입점(app 라우터)이 함 — 여기서는 이미 만든 루틴도 다룸
@riverpod
class PlaceRoutineActions extends _$PlaceRoutineActions {
  @override
  void build() {}

  /// 저장. 검증 오류가 있으면 저장하지 않고 오류 목록을 돌려줌
  Future<List<PlaceRoutineValidationError>> save({
    PlaceRoutine? existing,
    required String name,
    required List<String> placeIds,
    required bool isExclusive,
  }) async {
    final trimmedName = name.trim();
    final errors = [
      if (trimmedName.isEmpty) PlaceRoutineValidationError.emptyName,
      if (placeIds.isEmpty) PlaceRoutineValidationError.noPlaces,
    ];
    if (errors.isNotEmpty) {
      Diagnostics.log(
        'routine',
        'save rejected reason=${errors.map((e) => e.name).join(",")}',
      );
      return errors;
    }
    final routine = PlaceRoutine(
      id: existing?.id ?? IdGenerator.generate(),
      name: trimmedName,
      placeIds: placeIds,
      isExclusive: isExclusive,
      createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
    );
    await ref.read(placeRoutineRepositoryProvider).save(routine);
    Diagnostics.log(
      'routine',
      '${existing == null ? "added" : "updated"} id=${shortId(routine.id)} '
          'name=$trimmedName places=${placeIds.length} exclusive=$isExclusive',
    );
    return const [];
  }

  Future<void> delete(PlaceRoutine routine) async {
    await ref.read(placeRoutineRepositoryProvider).delete(routine.id);
    Diagnostics.log(
      'routine',
      'deleted id=${shortId(routine.id)} name=${routine.name}',
    );
  }

  /// 누르기: 켜짐이면 모두 끔, 아니면 모두 켬 (+ 나머지 끄기 옵션). 장소 상태가 루틴 상태
  Future<void> toggle(PlaceRoutine routine, List<AlertPlace> places) async {
    final changes = routine.toggleChanges(places);
    final turnedOn = !routine.isOnFor(places);
    final memberIds = routine.placeIds.toSet();
    final exclusiveOffCount = changes.entries
        .where((e) => !e.value && !memberIds.contains(e.key))
        .length;
    // 감시 동기화가 한 번만 돌게 한 번에 (장소 상태 전이 기록은 동기화 쪽이 남김)
    await ref.read(placeRepositoryProvider).setEnabledMany(changes);
    Diagnostics.log(
      'routine',
      'toggled id=${shortId(routine.id)} name=${routine.name} '
          'to=${turnedOn ? "on" : "off"} changed=${changes.length} '
          'exclusive_off=$exclusiveOffCount',
    );
  }
}
