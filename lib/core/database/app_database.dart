import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 생성 코드(app_database.g.dart)가 쓰는 타입들이다.
// `part` 파일은 이 파일의 import 스코프를 그대로 쓰므로, 여기에 없으면
// "Type 'AlertSchedule' not found" 로 빌드가 깨진다. analysis_options 가
// 생성 파일을 분석에서 제외하기 때문에 `flutter analyze` 는 통과하고
// 실제 컴파일에서만 터진다 — 지우지 않는다.
import '../domain/alert_schedule.dart';
import '../domain/alert_sound.dart';
import 'alert_schedule_converter.dart';
import 'alert_sound_converter.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// 앱 로컬 데이터베이스 (docs/03-DOMAIN.md 저장소 경계)
///
/// 백그라운드 진입점에서도 열린다 — 포그라운드 서비스·지오펜스 콜백은
/// UI 없이 실행되므로 이 클래스가 `BuildContext` 에 의존해서는 안 된다
/// (docs/02-ARCHITECTURE.md 규칙 5).
@DriftDatabase(
  tables: [AlertPlaces, GeofenceEvents, GeofenceStates, CustomSounds],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 테스트용 — 인메모리 DB 를 주입한다
  AppDatabase.forTesting(super.executor);

  /// v2 — `alert_places.schedules` 추가 (이슈 #81)
  /// v3 — `alert_places.sound` 추가 · `custom_sounds` 테이블 추가 (이슈 #121)
  @override
  int get schemaVersion => 3;

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
      if (from < 3) {
        // 기본값이 'preset:default' 라 기존 장소는 지금까지와 같은
        // 소리로 올라온다 — 사용자가 체감하는 변화가 없다
        await m.addColumn(alertPlaces, alertPlaces.sound);
        await m.createTable(customSounds);
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
