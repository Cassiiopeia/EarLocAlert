import 'package:drift/drift.dart';

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
