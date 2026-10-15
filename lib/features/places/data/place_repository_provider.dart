import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../domain/place_repository.dart';
import 'drift_place_repository.dart';

part 'place_repository_provider.g.dart';

/// 장소 저장소 — 화면은 인터페이스 타입을 받는다
@Riverpod(keepAlive: true)
PlaceRepository placeRepository(Ref ref) {
  return DriftPlaceRepository(ref.watch(appDatabaseProvider));
}
