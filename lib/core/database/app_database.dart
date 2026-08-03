import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// 앱 로컬 데이터베이스 (docs/03-DOMAIN.md 저장소 경계)
///
/// 백그라운드 진입점에서도 열린다 — 포그라운드 서비스·지오펜스 콜백은
/// UI 없이 실행되므로 이 클래스가 `BuildContext` 에 의존해서는 안 된다
/// (docs/02-ARCHITECTURE.md 규칙 5).
@DriftDatabase(tables: [AlertPlaces, GeofenceEvents, GeofenceStates])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 테스트용 — 인메모리 DB 를 주입한다
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ear_loc_alert.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
