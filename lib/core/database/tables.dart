import 'package:drift/drift.dart';

import 'alert_schedule_converter.dart';
import 'alert_sound_converter.dart';

/// 알림을 걸어둔 장소 (docs/03-DOMAIN.md)
@DataClassName('AlertPlaceRow')
class AlertPlaces extends Table {
  /// UUIDv7 — 앱에서 생성한다
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// 50 ~ 2000 (docs/01-REQUIREMENTS.md F1.4)
  IntColumn get radiusMeters => integer()();

  /// AlertDirection 인덱스
  IntColumn get direction => integer()();

  /// 삭제하지 않고 잠시 끄는 수단 (F1.7)
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();

  /// 이 장소에 쓸 알림음 (이슈 #121) — `preset:<id>` 또는 `custom:<uuid>`
  ///
  /// 기본값 `'preset:default'` 가 곧 기존 `assets/sounds/alert.wav` 다.
  /// 마이그레이션된 장소는 소리가 그대로다.
  TextColumn get sound => text()
      .map(const AlertSoundConverter())
      .withDefault(const Constant('preset:default'))();

  /// 알림이 활성인 시간 창 목록 (이슈 #81) — JSON 배열
  ///
  /// 기본값 `'[]'` 가 곧 "항상 활성"이다. 마이그레이션된 기존 장소가
  /// 이 값으로 올라오므로 사용자가 체감하는 변화가 없다.
  TextColumn get schedules => text()
      .map(const AlertScheduleListConverter())
      .withDefault(const Constant('[]'))();

  /// UTC (docs/04-CONVENTIONS.md)
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 진입/이탈 이력 (docs/03-DOMAIN.md)
///
/// F7(이력 조회)은 Phase 2 지만 이 기록은 MVP 부터 남긴다 —
/// "안 울렸다"는 문제를 조사할 유일한 수단이다.
@DataClassName('GeofenceEventRow')
class GeofenceEvents extends Table {
  TextColumn get id => text()();

  /// 값 참조 — 외래키를 걸지 않는다.
  /// 장소를 지워도 "언제 울렸는지" 기록은 남아야 조사가 가능하다.
  TextColumn get placeId => text()();

  /// GeofenceEventType 인덱스
  IntColumn get type => integer()();

  /// UTC
  DateTimeColumn get occurredAt => dateTime()();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// 판정 시점의 GPS 정확도 — 오작동 조사의 핵심 단서
  RealColumn get accuracyMeters => real()();

  /// 실제로 알림을 띄웠는지.
  /// 판정이 안 된 것인지, 판정은 됐는데 알림이 실패한 것인지를 가른다.
  BoolColumn get notified => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 장소별 지오펜스 현재 상태 (docs/03-DOMAIN.md)
///
/// **메모리에 두지 않는 것이 중요하다.** 재부팅하면 전부 `unknown` 이 되고,
/// 그러면 "밖에 있었다는 사실"이 사라져 첫 진입 알림을 놓친다.
@DataClassName('GeofenceStateRow')
class GeofenceStates extends Table {
  TextColumn get placeId => text()();

  /// GeofenceState 인덱스
  IntColumn get state => integer()();

  /// 마지막으로 상태가 갱신된 시각 (UTC)
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {placeId};
}

/// 사용자가 올린 알림음 (이슈 #121)
///
/// **파일 경로를 저장하지 않는다.** [id] 와 [fileExtension] 으로 재생 직전에
/// 조립한다 — 절대경로를 넣으면 앱 재설치·OS 업데이트로 컨테이너 경로가
/// 바뀌었을 때 전부 죽는다 (`CustomSoundFile.resolve`).
///
/// 행과 파일은 함께 움직인다. 한쪽만 남으면 목록에 있는데 소리가 안 나거나,
/// 지운 줄 알았는데 용량을 먹는다.
@DataClassName('CustomSoundRow')
class CustomSounds extends Table {
  /// UUIDv7. 저장된 파일 이름이기도 하다
  TextColumn get id => text()();

  /// 사용자가 고른 원본 파일명 — 화면에 보여주는 이름
  TextColumn get displayName => text().withLength(min: 1, max: 200)();

  /// 소문자 확장자 (`mp3` 등)
  TextColumn get fileExtension => text().withLength(min: 1, max: 10)();

  /// 등록할 때 실제 재생을 시도해서 얻은 길이
  IntColumn get durationMs => integer()();

  IntColumn get sizeBytes => integer()();

  /// UTC (docs/04-CONVENTIONS.md)
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
