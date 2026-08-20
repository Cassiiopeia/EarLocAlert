// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/di/providers.dart';
import '../../../core/domain/alert_direction.dart';
import '../../../core/domain/alert_schedule.dart';
import '../../../core/domain/id_generator.dart';
import '../domain/alert_place.dart';
import '../domain/place_validator.dart';

part 'place_list_controller.g.dart';

/// 위치 목록 스트림 (docs/04-CONVENTIONS.md — 화면 데이터는 Provider 에)
@riverpod
Stream<List<AlertPlace>> placeList(Ref ref) {
  return ref.watch(placeRepositoryProvider).watchAll();
}

/// 위치 조작 컨트롤러
@riverpod
class PlaceActions extends _$PlaceActions {
  @override
  void build() {}

  /// 저장. 검증 오류가 있으면 저장하지 않고 오류 목록을 반환한다.
  Future<List<PlaceValidationError>> save({
    String? id,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required AlertDirection direction,
    required bool soundEnabled,

    /// 빈 목록이면 항상 알림 (이슈 #81)
    List<AlertSchedule> schedules = const [],
  }) async {
    final repo = ref.read(placeRepositoryProvider);
    final isNew = id == null;

    final errors = PlaceValidator.validate(
      name: name,
      radiusMeters: radiusMeters,
      latitude: latitude,
      longitude: longitude,
      currentCount: await repo.count(),
      isNew: isNew,
      schedules: schedules,
    );
    if (errors.isNotEmpty) {
      Diagnostics.log(
        'place',
        '장소 저장 거부 name=$name 사유=${errors.map((e) => e.name).join(",")}',
      );
      return errors;
    }

    final existing = isNew ? null : await repo.findById(id);
    await repo.save(
      AlertPlace(
        // 저장 전에 앱이 식별자를 만든다 (docs/03-DOMAIN.md)
        id: id ?? IdGenerator.generate(),
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        direction: direction,
        soundEnabled: soundEnabled,
        schedules: schedules,
        enabled: existing?.enabled ?? true,
        createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
      ),
    );
    // 등록한 장소와 반경이 판정의 입력이다 — 어긋난 좌표를 나중에
    // 확인할 수 있어야 한다 (이슈 #106)
    Diagnostics.log(
      'place',
      '장소 ${isNew ? "추가" : "수정"} name=${name.trim()} '
          'lat=$latitude lng=$longitude radius=${radiusMeters}m '
          'direction=${direction.name} sound=$soundEnabled '
          'schedules=${schedules.length}건',
    );
    return const [];
  }

  /// 활성/비활성 토글 (F1.7) — 삭제하지 않고 잠시 끄는 수단
  Future<void> setEnabled(String id, {required bool enabled}) {
    // 꺼둔 장소는 감시되지 않는다 — "왜 안 울렸나"의 가장 단순한 답이다
    Diagnostics.log('place', '장소 ${enabled ? "켜짐" : "꺼짐"} id=$id');
    return ref.read(placeRepositoryProvider).setEnabled(id, enabled: enabled);
  }

  /// 삭제. 되돌리기(undo)를 위해 삭제된 장소를 반환한다.
  Future<AlertPlace?> delete(String id) async {
    final repo = ref.read(placeRepositoryProvider);
    final place = await repo.findById(id);
    if (place == null) return null;

    await repo.delete(id);
    // 장소가 사라지면 지오펜스 상태도 함께 지운다 (docs/03-DOMAIN.md)
    await ref.read(geofenceStateRepositoryProvider).remove(id);
    Diagnostics.log('place', '장소 삭제 name=${place.name}');
    return place;
  }

  /// undo — 삭제했던 장소를 그대로 되살린다
  Future<void> restore(AlertPlace place) {
    return ref.read(placeRepositoryProvider).save(place);
  }
}
