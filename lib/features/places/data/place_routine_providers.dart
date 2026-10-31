import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../domain/place_routine.dart';
import 'drift_place_routine_repository.dart';

part 'place_routine_providers.g.dart';

@Riverpod(keepAlive: true)
PlaceRoutineRepository placeRoutineRepository(Ref ref) =>
    DriftPlaceRoutineRepository(ref.watch(appDatabaseProvider));

/// 루틴 목록 (#315). 실패하면 빈 목록 (홈 칩 줄이 숨겨질 뿐)
@riverpod
Stream<List<PlaceRoutine>> placeRoutineList(Ref ref) =>
    ref.watch(placeRoutineRepositoryProvider).watchAll();
