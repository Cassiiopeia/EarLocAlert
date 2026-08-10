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

  /// v2 — `alert_places.schedules` 추가 (이슈 #81)
  @override
  int get schemaVersion => 2;

  /// 기존 사용자의 데이터를 살린 채 컬럼을 더한다.
  ///
  /// **재생성(`deleteEverything`)을 쓰지 않는다.** 장소를 잃으면 사용자는
  /// 앱을 다시 설정해야 하고, 지오펜스 상태까지 날아가 첫 진입 알림을
  /// 놓친다 (docs/03-DOMAIN.md).
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // 컬럼 기본값이 '[]' 이므로 기존 장소는 전부 "항상 활성"으로
        // 올라온다 — 동작이 바뀌지 않는다
        await m.addColumn(alertPlaces, alertPlaces.schedules);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ear_loc_alert.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
