import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/domain/alert_direction.dart';
import '../core/domain/retention_policy.dart';
import '../features/geofence/data/geofence_event_repository_provider.dart';
import '../features/geofence/domain/geofence_event.dart';
import '../features/history/domain/arrival_record.dart';
import '../features/places/data/place_repository_provider.dart';

part 'arrival_history_provider.g.dart';

/// 도착 기록 (#313): 울린 이력(geofence) + 장소 이름(places) > 화면 값. 두 feature 를 app 이 묶음
///
/// 보관 기간(90일) 안의 것만. 실패하면 빈 목록 + 기록 (화면은 빈 상태로)
@riverpod
Future<List<ArrivalRecord>> arrivalHistory(Ref ref) async {
  try {
    final events = await ref
        .read(geofenceEventRepositoryProvider)
        .findNotified(sinceUtc: RetentionPolicy.cutoffFrom(DateTime.now()));
    final places = await ref.read(placeRepositoryProvider).findAll();
    final nameById = {for (final place in places) place.id: place.name};
    final records = [
      for (final event in events)
        ArrivalRecord(
          placeId: event.placeId,
          placeName: nameById[event.placeId],
          direction: event.type == GeofenceEventType.exited
              ? AlertDirection.exit
              : AlertDirection.enter,
          occurredAtUtc: event.occurredAt,
        ),
    ];
    final deletedCount = records.where((r) => r.placeName == null).length;
    Diagnostics.log(
      'history',
      'loaded records=${records.length} deleted_places=$deletedCount',
    );
    return records;
  } on Object catch (error) {
    Diagnostics.log('history', 'load failed error=$error');
    return const [];
  }
}
